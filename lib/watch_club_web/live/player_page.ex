defmodule WatchClubWeb.PlayerPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Live.Player.PlayerComponents

  @playback_session_fields [
    active_playback: [
      media: [
        video: [
          movie: [:best_localization],
          tv_show_episode: [tv_show: [:best_localization]]
        ]
      ]
    ]
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <main class="fixed inset-0 grid place-items-center overflow-hidden bg-black text-white">
      <div
        :if={@session}
        id="watch-club-player"
        phx-hook="Player"
        phx-update="ignore"
        data-vidstack-src={~p"/assets/js/player_vidstack.js"}
        class="size-full"
      >
        <media-player
          id="watch-club-vidstack-player"
          data-player-media
          data-src={~p"/player/hls/#{@session.id}/master.m3u8"}
          title={playback_title(@session)}
          duration={@session.active_playback.media.video.duration_seconds}
          preload="metadata"
          playsinline
          class="group/player relative block size-full overflow-hidden bg-black outline-none [&[data-started]:not([data-controls])]:cursor-none"
        >
          <media-provider class="absolute inset-0 block [&_video]:size-full [&_video]:object-contain">
          </media-provider>

          <%!-- On touch, a tap toggles play/pause only while the controls are showing
                (data-controls). When they're hidden the gesture is display:none, so its
                hit-test misses, the tap falls through to Vidstack's native control reveal
                (with auto-hide), and nothing is paused. Hover pointers always pause. --%>
          <media-gesture
            event="pointerup"
            action="toggle:paused"
            class="absolute inset-0 z-10 hidden group-data-controls/player:block [@media(hover:hover)]:block"
            aria-hidden="true"
          >
          </media-gesture>

          <media-captions class="pointer-events-none absolute inset-x-4 bottom-32 z-20 mx-auto block max-w-[80%] text-center text-lg font-semibold [text-shadow:0_2px_4px_rgb(0_0_0/0.85)] sm:text-2xl">
          </media-captions>

          <.player_loader class="absolute inset-0 z-20 opacity-0 transition-opacity group-data-buffering/player:opacity-100" />

          <media-controls
            data-visible="true"
            hide-delay="3000"
            class="pointer-events-none absolute inset-0 z-30 flex flex-col justify-between bg-linear-to-t from-black/70 via-transparent to-black/70 opacity-0 transition-opacity data-visible:opacity-100"
          >
            <.controls_header video={@session.active_playback.media.video} />
            <.controls_center_row />
            <.controls_footer session={@session} />
          </media-controls>

          <media-announcer></media-announcer>
        </media-player>
      </div>

      <.player_load_error_overlay :if={@player_error or @playback_error} />

      <.player_loader :if={is_nil(@session) and not @player_error} class="absolute inset-0" />
    </main>
    """
  end

  @impl true
  def mount(%{"media_id" => media_id}, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "WatchClub Player")
      |> assign(:session, nil)
      |> assign(:player_error, false)
      |> assign(:playback_error, false)

    if connected?(socket) do
      start_player_session(socket, media_id)
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("player_ready", _params, socket) do
    {:noreply, assign(socket, :playback_error, false)}
  end

  @impl true
  def handle_event("player_failed", _params, socket) do
    {:noreply, assign(socket, :playback_error, true)}
  end

  @impl true
  def handle_event("player_heartbeat", params, socket) do
    with %{} = session <- socket.assigns.session do
      Playbacks.heartbeat_session(session, %{position_seconds: params["position_seconds"]},
        actor: socket.assigns.current_user
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("player_stop", params, socket) do
    {:reply,
     stop_session(
       socket.assigns.current_user,
       socket.assigns.session,
       params["position_seconds"]
     ), socket}
  end

  defp start_player_session(socket, media_id) do
    actor = socket.assigns.current_user

    case Playbacks.start_session(media_id, load: @playback_session_fields, actor: actor) do
      {:ok, %{active_playback: %{}} = session} ->
        socket =
          socket
          |> assign(:session, session)
          |> assign(:player_error, false)
          |> assign(:playback_error, false)

        {:ok, socket}

      {:error, reason} ->
        Logger.warning("Could not start Playback Session: #{inspect(reason)}")
        {:ok, assign(socket, :player_error, true)}
    end
  end

  defp playback_title(session), do: Path.basename(session.active_playback.media.path)

  defp stop_session(actor, %Session{} = session, position) do
    case Playbacks.close_session(session, %{position_seconds: position}, actor: actor) do
      {:ok, _session} -> %{ok: true}
      {:error, %Ash.Error.Forbidden{}} -> %{ok: true}
      {:error, reason} -> %{ok: false, error: inspect(reason)}
    end
  end

  defp stop_session(_actor, _session, _position), do: %{ok: true}
end
