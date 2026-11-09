defmodule WatchClubWeb.HomePage do
  @moduledoc """
  Home: what's up next for the User, and what's happening in WatchClub. Signing in opens it.

  The latest Content in progress fills the spotlight. Below, Up next, For You and New in the
  library sit beside Watching Now and the Activity Feed, or above them in a narrow page. Watching
  Now loads with the page.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.PosterCard
  import WatchClubWeb.HomePage.{ActivityFeed, ContinueWatching, ForYou, WatchingNow}

  alias WatchClub.ActivityFeed.Events.ContentWatchedEvent
  alias WatchClub.Conversations
  alias WatchClub.Conversations.{Message, Participant}
  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive
  alias WatchClubWeb.Helpers.KeysetStreamState

  # The spotlight's Content, then Up next
  @in_progress_limit 6
  @new_in_library_limit 12
  @feed_page_size 8

  @new_in_library_load [
    :implementation,
    :actor_progress_status,
    actor_recommendations: [:recommended_by]
  ]

  # What For You shows, as the navigation's badges count it
  @for_you_resources [Message, Participant, RequestSubscriber, PlaylistAccess]

  @impl true
  def render(assigns) do
    %{in_progress: in_progress, for_you: for_you, new_in_library: new_in_library} = assigns

    assigns =
      assign(
        assigns,
        :empty?,
        in_progress == [] and for_you == [] and new_in_library == [] and
          assigns.watching_now == [] and assigns.feed_empty?
      )

    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      title={dgettext("nav", "Home")}
      space="section"
      class="max-w-layout-page @container"
    >
      <:hero>
        <.spotlight
          :if={@in_progress != []}
          content={hd(@in_progress)}
          locale={@current_user.settings.locale}
        />
      </:hero>

      <.empty :if={@empty?} id="home-empty">
        <:icon><Lucideicons.popcorn /></:icon>
        <:title>{dgettext("home", "Nothing has happened yet")}</:title>
        <:description>
          {dgettext("home", "What people watch and what joins the library will show up here.")}
        </:description>
        <.button id="home-empty-browse" variant="secondary" navigate={~p"/browse"}>
          <:icon><Lucideicons.clapperboard /></:icon>
          {dgettext("nav", "Browse")}
        </.button>
      </.empty>

      <div :if={!@empty?} class="flex min-w-0 flex-col gap-section @4xl:flex-row @4xl:items-start">
        <div class="flex min-w-0 flex-1 flex-col gap-section">
          <.up_next
            :if={length(@in_progress) > 1}
            contents={tl(@in_progress)}
            locale={@current_user.settings.locale}
          />
          <.for_you :if={@for_you != []} items={@for_you} locale={@current_user.settings.locale} />
          <.page_section
            :if={@new_in_library != []}
            id="new-in-library-title"
            title={dgettext("home", "New in the library")}
          >
            <.scroll_row id="new-in-library">
              <div
                :for={content <- @new_in_library}
                id={"new-in-library-#{content.id}"}
                class="w-28 shrink-0 snap-start @3xl:w-36"
              >
                <.poster_card content={content} locale={@current_user.settings.locale}>
                  <:action>
                    <.live_component
                      id={PlayOrRequestButtonLive.dom_id(ContentIdentity.from_content(content))}
                      module={PlayOrRequestButtonLive}
                      content_identity={ContentIdentity.from_content(content)}
                      current_user={@current_user}
                      variant="poster"
                    />
                  </:action>
                </.poster_card>
              </div>
            </.scroll_row>
          </.page_section>
        </div>

        <div
          :if={@watching_now != [] or !@feed_empty?}
          class="@container flex min-w-0 flex-col gap-section @4xl:w-80 @4xl:shrink-0"
        >
          <.watching_now :if={@watching_now != []} sessions={@watching_now} />
          <.activity_feed
            :if={!@feed_empty?}
            stream={@streams.feed}
            more?={KeysetStreamState.can_load_more?(@feed_state)}
            locale={@current_user.settings.locale}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> WatchClub.PubSub.subscribe_to_current_user_content_topics()
     |> WatchClub.PubSub.subscribe_if_connected("feed:global")
     # Intentionally small: one line per User
     |> assign(:watching_now, Playbacks.list_watching_now!(load: session_load(), actor: user))
     |> stream_configure(:feed, dom_id: &feed_entry_dom_id(&1.group_key))
     |> assign(:feed_state, KeysetStreamState.init(@feed_page_size))
     |> load_feed_page()
     |> load_in_progress()
     |> load_for_you()
     |> load_new_in_library()}
  end

  @impl true
  def handle_event("load_activity_feed_page", _params, socket) do
    if KeysetStreamState.can_load_more?(socket.assigns.feed_state),
      do: {:noreply, load_feed_page(socket)},
      else: {:noreply, socket}
  end

  @impl true
  def handle_info(%Notification{} = notification, socket) do
    PlayOrRequestButtonLive.handle_pubsub_message(notification, socket.assigns.current_user)
    {:noreply, reload_after(socket, notification)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # A Feed Event joined or left a Feed Entry: reload the entry. A new event moves its entry to the
  # top. A removed one updates the entry in place, or removes it once it has no events left.
  defp reload_after(socket, %Notification{
         resource: ContentWatchedEvent,
         action: action,
         data: %{group_key: key}
       }) do
    entry = ActivityFeed.get_user_feed_entry!(key, actor: socket.assigns.current_user)

    case {action.type, entry} do
      {_type, nil} ->
        stream_delete_by_dom_id(socket, :feed, feed_entry_dom_id(key))

      {:create, entry} ->
        socket
        |> stream_delete(:feed, entry)
        |> stream_insert(:feed, entry, at: 0)
        |> assign(:feed_empty?, false)

      {:destroy, entry} ->
        stream_insert(socket, :feed, entry, update_only: true)
    end
  end

  defp reload_after(socket, %Notification{resource: resource})
       when resource in [Media, WatchProgress],
       do: socket |> load_in_progress() |> load_new_in_library()

  defp reload_after(socket, %Notification{resource: resource})
       when resource in @for_you_resources,
       do: load_for_you(socket)

  defp reload_after(socket, _notification), do: socket

  defp load_in_progress(socket) do
    in_progress =
      Contents.get_user_recently_watched!(
        load: content_load(),
        query: [limit: @in_progress_limit],
        actor: socket.assigns.current_user
      )

    # Intentionally small: @in_progress_limit Contents
    assign(socket, :in_progress, in_progress)
  end

  defp load_for_you(socket) do
    user = socket.assigns.current_user

    conversations =
      Conversations.list_conversations!(%{unread?: true}, load: conversation_load(), actor: user)

    requests =
      Requests.list_current_user_ready_unseen_requests!(load: request_load(), actor: user)

    playlists =
      Playlists.list_playlists!(
        query: [filter: [shared_unseen_for_actor?: true]],
        load: playlist_load(),
        actor: user
      )

    # Intentionally small: what the navigation's badges count
    assign(socket, :for_you, conversations ++ requests ++ playlists)
  end

  defp load_new_in_library(socket) do
    new_in_library =
      Contents.get_contents_in_library!(
        load: @new_in_library_load,
        query: [limit: @new_in_library_limit],
        actor: socket.assigns.current_user
      )

    # Intentionally small: @new_in_library_limit Contents
    assign(socket, :new_in_library, new_in_library)
  end

  defp load_feed_page(socket) do
    state = socket.assigns.feed_state

    {:ok, new_state, entries} =
      KeysetStreamState.load_page(state, fn page ->
        ActivityFeed.get_user_activity_feed(actor: socket.assigns.current_user, page: page)
      end)

    socket
    |> assign(:feed_state, new_state)
    |> assign(:feed_empty?, state.status == :init and entries == [])
    |> stream(:feed, entries, reset: state.status == :init)
  end

  defp feed_entry_dom_id(group_key), do: "feed-entry-#{group_key}"
end
