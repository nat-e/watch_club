defmodule WatchClubWeb.HomePage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Live.Home.{ActivityFeed, ContinueWatchingSection}

  alias Ash.Notifier.Notification
  alias Phoenix.Socket.Broadcast

  alias WatchClub.ActivityFeed
  alias WatchClub.ActivityFeed.Event
  alias WatchClub.ActivityFeed.Preparations.LoadActivityFeedEvent

  alias WatchClubWeb.Helpers.KeysetStreamState

  @continue_watching_max_items 6
  @feed_page_size 25

  @continue_watching_content_load [
    movie: [:actor_progress, :videos],
    tv_show: [actor_next_episode: [:has_media?, :actor_progress, :videos]]
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      space="section"
      class="max-w-panel"
    >
      <.continue_watching_section
        :if={@continue_watching != []}
        contents={@continue_watching}
        current_user={@current_user}
      />
      <.activity_feed
        stream={@streams.feed}
        current_user={@current_user}
        stream_state={@feed_stream_state}
      />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    subscribe_to_activity_feed_topics(socket)

    {:ok,
     socket
     |> stream_configure(:feed, dom_id: & &1.id)
     |> assign(feed_stream_state: KeysetStreamState.init(@feed_page_size))
     |> load_feed_page()
     |> load_continue_watching()}
  end

  @impl true
  def handle_info(%Broadcast{payload: %Notification{data: %Event{} = event}}, socket) do
    # A new activity feed event has been received
    # Load the required fields (for some reason using load: option in pub_sub does not seem to work)
    # and prepend it to the stream
    event =
      event
      |> Ash.load!(LoadActivityFeedEvent.load_statement(), actor: socket.assigns.current_user)

    {:noreply, socket |> stream_insert(:feed, event, at: 0)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_activity_feed_page", _params, socket) do
    {:noreply, socket |> load_feed_page()}
  end

  defp load_continue_watching(socket) do
    continue_watching =
      Contents.get_user_recently_watched!(
        actor: socket.assigns.current_user,
        query: [
          load: @continue_watching_content_load,
          limit: @continue_watching_max_items
        ]
      )

    socket |> assign(continue_watching: continue_watching)
  end

  defp load_feed_page(socket) do
    stream_state = socket.assigns.feed_stream_state
    reset = stream_state.status == :init

    {:ok, new_state, items} =
      KeysetStreamState.load_page(stream_state, fn page_options ->
        ActivityFeed.get_user_activity_feed(
          actor: socket.assigns.current_user,
          page: page_options
        )
      end)

    socket
    |> assign(:feed_stream_state, new_state)
    |> stream(:feed, items, reset: reset)
  end

  defp subscribe_to_activity_feed_topics(socket) do
    user = socket.assigns.current_user

    # Subscribe to all the clubs of this user, plus their private and global feed topics
    topics =
      Enum.map(
        user.memberships,
        &"activity_feed_events:club:#{&1.club_id}"
      ) ++ ["activity_feed_events:global", "activity_feed_events:user:#{user.id}"]

    WatchClub.PubSub.subscribe_if_connected(socket, topics)
  end
end
