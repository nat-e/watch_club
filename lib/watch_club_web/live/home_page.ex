defmodule WatchClubWeb.HomePage do
  @moduledoc """
  Home: what's up next for the User, and what's happening in WatchClub. Signing in opens it.

  The latest of the User's Continue Watching fills the spotlight. Below, Up next with the rest of
  it, For You, New in the library and New sports events sit beside Watching Now and the Activity
  Feed, or above them in a narrow page. Sports Events have their own row, as they arrive far more
  often than Movies and TV Shows. Watching Now loads with the page.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.PosterCard
  import WatchClubWeb.HomePage.{ActivityFeed, ContinueWatching, ForYou, WatchingNow}

  alias WatchClub.ActivityFeed.Events.ContentWatchedEvent
  alias WatchClub.Conversations
  alias WatchClub.Conversations.Participant
  alias WatchClub.History.HiddenFromContinueWatching
  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive
  alias WatchClubWeb.Helpers.KeysetStreamState
  alias WatchClubWeb.HomePage.ForYou

  # The spotlight's Content, then Up next
  @in_progress_limit 6
  @new_in_library_limit 12
  @for_you_limit 5
  @feed_page_size 8

  @new_in_library_load [
    :title,
    :poster_path,
    :actor_progress_status,
    :incomplete?,
    actor_recommendations: [:recommended_by]
  ]

  # A recommendation to the User, a Content Request being Completed, a Playlist shared with them,
  # and its name and Content
  @for_you_resources [Participant, RequestSubscriber, PlaylistAccess, Playlist, PlaylistItem]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      playback_session={@playback_session}
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

      <div class="flex min-w-0 flex-col gap-section @4xl:flex-row @4xl:items-start">
        <div class="flex min-w-0 flex-1 flex-col gap-section">
          <.up_next
            :if={length(@in_progress) > 1}
            contents={tl(@in_progress)}
            locale={@current_user.settings.locale}
          />
          <.for_you items={@for_you} locale={@current_user.settings.locale} />
          <.new_in_library_row
            :if={@new_in_library != []}
            id="new-in-library"
            title={dgettext("home", "New on %{name}", name: @instance_settings.name)}
            contents={@new_in_library}
            current_user={@current_user}
          />
          <.new_in_library_row
            :if={@new_sports_events != []}
            id="new-sports-events"
            title={dgettext("home", "New sports events")}
            contents={@new_sports_events}
            current_user={@current_user}
          />
          <.empty :if={@new_in_library == [] and @new_sports_events == []} id="library-empty">
            <:icon><Lucideicons.popcorn /></:icon>
            <:title>{dgettext("home", "Nothing in the library yet")}</:title>
            <:description>
              {dgettext(
                "home",
                "Request the movies and TV shows you'd like to watch. We'll look for them and add them here for everyone."
              )}
            </:description>
            <.button id="library-empty-browse" variant="secondary" navigate={~p"/browse"}>
              <:icon><Lucideicons.clapperboard /></:icon>
              {dgettext("nav", "Browse")}
            </.button>
          </.empty>
        </div>

        <div class={[
          "@container flex min-w-0 flex-col gap-section @4xl:w-80 @4xl:shrink-0",
          @watching_now == [] && "not-has-[[data-activity]]:hidden"
        ]}>
          <.watching_now :if={@watching_now != []} watchers={@watching_now} />
          <.activity_feed
            stream={@streams.feed}
            more?={KeysetStreamState.can_load_more?(@feed_state)}
            locale={@current_user.settings.locale}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :contents, :list, required: true, doc: "with `@new_in_library_load` loaded"
  attr :current_user, User, required: true

  defp new_in_library_row(assigns) do
    ~H"""
    <.page_section id={"#{@id}-title"} title={@title}>
      <.scroll_row id={@id}>
        <div
          :for={content <- @contents}
          id={"#{@id}-#{content.id}"}
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
     |> assign(:watching_now, Playbacks.list_watching_now!(actor: user))
     |> stream_configure(:feed, dom_id: &feed_entry_dom_id(&1.group_key))
     |> assign(:feed_state, KeysetStreamState.init(@feed_page_size))
     |> load_feed_page()
     |> load_in_progress()
     |> load_for_you()
     |> load_new_in_library()}
  end

  @impl true
  def handle_event("hide_from_continue_watching", %{"content_id" => content_id}, socket) do
    hidden =
      History.hide_from_continue_watching!(content_id,
        load: [content: :title],
        actor: socket.assigns.current_user
      )

    # The notification of the hiding reloads Continue Watching
    {:noreply,
     put_flash(
       socket,
       :info,
       dgettext("home", "%{title} is hidden until you play it again.",
         title: hidden.content.title
       )
     )}
  end

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

  # A Feed Event joined a Feed Entry: reload the entry and move it to the top
  defp reload_after(socket, %Notification{resource: ContentWatchedEvent, data: %{group_key: key}}) do
    entry = ActivityFeed.get_user_feed_entry!(key, actor: socket.assigns.current_user)
    socket |> stream_delete(:feed, entry) |> stream_insert(:feed, entry, at: 0)
  end

  defp reload_after(socket, %Notification{resource: resource})
       when resource in [Media, WatchProgress],
       do: socket |> load_in_progress() |> load_new_in_library()

  defp reload_after(socket, %Notification{resource: HiddenFromContinueWatching}),
    do: load_in_progress(socket)

  defp reload_after(socket, %Notification{resource: resource})
       when resource in @for_you_resources,
       do: load_for_you(socket)

  defp reload_after(socket, _notification), do: socket

  defp load_in_progress(socket) do
    in_progress =
      Contents.get_actor_continue_watching!(
        load: content_load(),
        actor: socket.assigns.current_user
      )
      |> Enum.take(@in_progress_limit)

    # Intentionally small: @in_progress_limit Contents
    assign(socket, :in_progress, in_progress)
  end

  # The latest of each kind, so the latest of all is among them
  defp load_for_you(socket) do
    user = socket.assigns.current_user

    conversations =
      Conversations.list_recommendations_to_current_user!(
        load: conversation_load(),
        query: [limit: @for_you_limit],
        actor: user
      )

    requests =
      Requests.list_current_user_completed_requests_in_library!(
        load: request_load(),
        query: [limit: @for_you_limit],
        actor: user
      )

    playlists =
      Playlists.list_playlists_shared_with_current_user!(
        load: playlist_load(),
        query: [limit: @for_you_limit],
        actor: user
      )

    socket
    # Intentionally small: @for_you_limit items
    |> assign(:for_you, ForYou.latest(conversations ++ requests ++ playlists, @for_you_limit))
    |> WatchClub.PubSub.subscribe_to_playlists(playlists)
  end

  defp load_new_in_library(socket) do
    load = fn content_type ->
      Contents.get_new_in_library!(%{content_type: content_type},
        load: @new_in_library_load,
        query: [limit: @new_in_library_limit],
        actor: socket.assigns.current_user
      )
    end

    # Intentionally small: @new_in_library_limit Contents each
    socket
    |> assign(:new_in_library, load.(:movies_and_shows))
    |> assign(:new_sports_events, load.(:sports_events))
  end

  defp load_feed_page(socket) do
    state = socket.assigns.feed_state

    {:ok, new_state, entries} =
      KeysetStreamState.load_page(state, fn page ->
        ActivityFeed.get_user_activity_feed(actor: socket.assigns.current_user, page: page)
      end)

    socket
    |> assign(:feed_state, new_state)
    |> stream(:feed, entries, reset: state.status == :init)
  end

  defp feed_entry_dom_id(group_key), do: "feed-entry-#{group_key}"
end
