defmodule WatchClubWeb.HomePage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Live.Home.{ActivityFeed, ContinueWatching}

  alias WatchClubWeb.Helpers.KeysetStreamState

  @continue_watching_max_items 6
  @feed_page_size 25

  # The fields that need to be loaded on the Content objects for the continue watching section
  @media_fields [:has_media?, :actor_progress, :videos]
  @continue_watching_content_fields [
    implementation: %{
      load: [
        movie: @media_fields,
        tv_show: [actor_next_episode: @media_fields]
      ]
    }
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      space="section"
      class="max-w-layout-page @container"
    >
      <:hero>
        <h1 class="sr-only">{dgettext("home", "Home")}</h1>
        <.spotlight
          :if={@continue_watching != []}
          content={hd(@continue_watching)}
          locale={@current_user.settings.locale}
        />
      </:hero>
      <.up_next
        :if={length(@continue_watching) > 1}
        contents={tl(@continue_watching)}
        locale={@current_user.settings.locale}
      />
      <.activity_feed
        stream={@streams.feed}
        current_user={@current_user}
        stream_state={@feed_stream_state}
        instance_settings={@instance_settings}
      />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> subscribe_to_activity_feed_topics()
     |> WatchClub.PubSub.subscribe_to_current_user_content_topics()
     |> stream_configure(:feed, dom_id: &feed_entry_dom_id(&1.group_key))
     |> load_feed_page()
     |> load_continue_watching()}
  end

  # A Feed Event joined or left a Feed Entry: reload the entry. A new event moves its entry to the
  # top. A removed one updates the entry in place, or removes it once the user can't see any of
  # its events.
  @impl true
  def handle_info(%Notification{action: action, data: %FeedEventScope{group_key: key}}, socket) do
    entry = ActivityFeed.get_user_feed_entry!(key, actor: socket.assigns.current_user)

    socket =
      case {action.type, entry} do
        {_type, nil} ->
          stream_delete_by_dom_id(socket, :feed, feed_entry_dom_id(key))

        {:create, entry} ->
          socket |> stream_delete(:feed, entry) |> stream_insert(:feed, entry, at: 0)

        {:destroy, entry} ->
          stream_insert(socket, :feed, entry, update_only: true)
      end

    {:noreply, socket}
  end

  def handle_info(%Notification{resource: WatchProgress}, socket) do
    {:noreply, socket |> load_continue_watching()}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_activity_feed_page", _params, socket) do
    if KeysetStreamState.can_load_more?(socket.assigns.feed_stream_state) do
      {:noreply, socket |> load_feed_page()}
    else
      {:noreply, socket}
    end
  end

  defp load_continue_watching(socket) do
    continue_watching =
      Contents.get_user_recently_watched!(
        actor: socket.assigns.current_user,
        query: [
          load: @continue_watching_content_fields,
          limit: @continue_watching_max_items
        ]
      )

    # A plain list: it holds at most @continue_watching_max_items Contents
    socket |> assign(continue_watching: continue_watching)
  end

  defp load_feed_page(socket) do
    stream_state = socket.assigns[:feed_stream_state] || KeysetStreamState.init(@feed_page_size)

    {:ok, new_state, items} =
      KeysetStreamState.load_page(stream_state, fn page_options ->
        ActivityFeed.get_user_activity_feed(
          actor: socket.assigns.current_user,
          page: page_options
        )
      end)

    socket
    |> assign(:feed_stream_state, new_state)
    |> stream(:feed, items, reset: stream_state.status == :init)
  end

  defp feed_entry_dom_id(group_key), do: "feed-entry-#{group_key}"

  defp subscribe_to_activity_feed_topics(socket) do
    user = socket.assigns.current_user

    # Subscribe to this user's personal feed topic plus all the clubs they belong to
    topics = ["feed:user:#{user.id}" | Enum.map(user.memberships, &"feed:club:#{&1.club_id}")]

    WatchClub.PubSub.subscribe_if_connected(socket, topics)
  end
end
