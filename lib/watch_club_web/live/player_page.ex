defmodule WatchClubWeb.PlayerPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Live.Player.PlayerComponents

  alias WatchClubWeb.Live.Player.ReportProblemLive

  @playback_session_fields [
    active_playback: [
      media: [
        video: [
          :markers,
          :credits_start_seconds,
          movie: [:best_localization, :actor_progress],
          tv_show_episode: [
            :actor_progress,
            tv_show: [:best_localization],
            next_episode: [:has_media?, :videos],
            previous_episode: [:has_media?, :videos]
          ]
        ]
      ]
    ]
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <main class="relative grid h-dvh place-items-center overflow-hidden bg-black text-white">
      <div
        :if={@session}
        id="watch-club-player"
        phx-hook="Player"
        data-videojs-src={~p"/assets/js/player_videojs.js"}
        data-src={hls_master_playlist_url(@session.active_playback)}
        data-thumbnails-src={thumbnails_url(@session.active_playback)}
        data-start-position={@start_position_seconds}
        class="size-full"
      >
        <%!-- Video.js sets the attributes and fills the children of its elements, which
              LiveView would undo: the ones holding server content ignore attribute changes,
              the others sit in phx-update="ignore" containers --%>
        <media-i18n class="contents">
          <video-player class="contents">
            <%!-- The browser draws the captions, raised by the footer's height while the controls show --%>
            <media-container
              phx-mounted={JS.ignore_attributes("*")}
              class="@container/player group/player relative block size-full overflow-hidden bg-black focus-visible:-outline-offset-2 not-data-controls-visible:cursor-none [--media-caption-track-duration:150ms] data-controls-visible:[--media-caption-track-y:calc(--spacing(24)*-1)] has-[[data-show-from][data-active]]:[--media-caption-track-y:calc(--spacing(44)*-1)]!"
            >
              <div id="watch-club-player-media" phx-update="ignore" class="contents">
                <hlsjs-video preload="metadata" playsinline autoplay class="absolute inset-0 block">
                </hlsjs-video>

                <media-gesture type="tap" action="togglePaused" pointer="mouse" />
                <media-gesture type="tap" action="toggleControls" pointer="touch" />
                <media-hotkey keys="k" action="togglePaused" target="document" />
                <media-hotkey keys="Space" action="togglePaused" target="document" />
                <media-hotkey keys="m" action="toggleMuted" target="document" />
                <media-hotkey keys="f" action="toggleFullscreen" target="document" />
                <media-hotkey keys="ArrowLeft" action="seekStep" value="-10" target="document" />
                <media-hotkey keys="ArrowRight" action="seekStep" value="10" target="document" />

                <media-buffering-indicator class="absolute inset-0 z-20 opacity-0 transition-opacity data-visible:opacity-100">
                  <.player_loader class="size-full" />
                </media-buffering-indicator>

                <media-status-announcer class="sr-only" />
              </div>

              <%!-- Before the controls, so a prompt is the first Tab stop --%>
              <.skip_marker_buttons video={@session.active_playback.media.video} />
              <.up_next_button
                playback_id={@session.active_playback.id}
                video={@session.active_playback.media.video}
              />

              <media-controls
                phx-mounted={JS.ignore_attributes("*")}
                class="group/controls pointer-events-none absolute inset-0 z-30 flex flex-col justify-between bg-linear-to-t from-black/80 via-transparent to-black/80 opacity-0 transition-opacity data-visible:opacity-100 has-focus-visible:opacity-100"
              >
                <.controls_header video={@session.active_playback.media.video} />
                <.controls_center_row />
                <.controls_footer
                  playback_id={@session.active_playback.id}
                  video={@session.active_playback.media.video}
                />
              </media-controls>
            </media-container>
          </video-player>
        </media-i18n>
      </div>

      <.player_load_error_overlay :if={@playback_error} />

      <.player_loader :if={!@session} class="absolute inset-0" />

      <.live_component
        :if={@problem_details}
        module={ReportProblemLive}
        id="report-problem"
        details={@problem_details}
        category={if @playback_error, do: :player}
        current_user={@current_user}
        on_close={JS.push("close_problem_report")}
      />
    </main>

    <.flash flash={@flash} />
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    # The Problem Reports of this Player record its browser
    {:ok, assign(socket, user_agent: get_connect_info(socket, :user_agent), problem_details: nil)}
  end

  @impl true
  def handle_params(%{"media_id" => media_id} = params, _uri, socket) do
    cond do
      # Don't load the player on the initial server-side render
      !connected?(socket) ->
        {:noreply, socket |> assign(:session, nil) |> assign(:playback_error, false)}

      # Initial player load, create a session
      is_nil(socket.assigns[:session]) ->
        {:noreply, socket |> start_player_session(media_id, params["t"])}

      # A session already exist but the video has changed, update the session
      media_id != socket.assigns.session.active_playback.media_id ->
        {:noreply, socket |> start_new_playback_for_session(media_id)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("player_ready", _params, socket) do
    {:noreply, socket |> assign(:playback_error, false)}
  end

  def handle_event("player_failed", _params, socket) do
    {:noreply, socket |> assign(:playback_error, true)}
  end

  # The hook paused the video and sends what the Player shows: nothing when it never played
  def handle_event("report_problem", shown, socket) do
    details = %{
      playback_id: socket.assigns.session.active_playback.id,
      position_seconds: shown["position_seconds"],
      audio: shown["audio"],
      subtitles: shown["subtitles"],
      quality: shown["quality"],
      user_agent: socket.assigns.user_agent
    }

    {:noreply, assign(socket, :problem_details, details)}
  end

  def handle_event("close_problem_report", _params, socket),
    do: {:noreply, assign(socket, :problem_details, nil)}

  def handle_event("player_heartbeat", params, socket) do
    # Best effort, don't crash the process if heartbeat fails
    Playbacks.heartbeat_session(
      socket.assigns.session,
      %{position_seconds: params["position_seconds"]},
      actor: socket.assigns.current_user
    )

    {:noreply, socket}
  end

  # A click or the countdown that arrives once the next episode started must not skip another one
  def handle_event("play_next_episode", %{"playback_id" => playback_id}, socket) do
    %Playback{id: active_id, media: %{video: video}} = socket.assigns.session.active_playback
    next_episode = video.tv_show_episode && video.tv_show_episode.next_episode

    if playback_id == active_id,
      do: {:noreply, socket |> switch_episode(next_episode)},
      else: {:noreply, socket}
  end

  def handle_event("play_previous_episode", _params, socket) do
    video = socket.assigns.session.active_playback.media.video
    previous_episode = video.tv_show_episode && video.tv_show_episode.previous_episode

    {:noreply, socket |> switch_episode(previous_episode)}
  end

  # The Markers of the Video playing are found in the background after its import
  @impl true
  def handle_info(%Notification{resource: Marker, data: %Marker{video_id: video_id}}, socket) do
    %{session: session, current_user: user} = socket.assigns

    if session.active_playback.media_id == video_id do
      video =
        Ash.load!(session.active_playback.media.video, [:markers, :credits_start_seconds],
          actor: user
        )

      {:noreply, assign(socket, :session, put_in(session.active_playback.media.video, video))}
    else
      {:noreply, socket}
    end
  end

  def handle_info({ReportProblemLive, :reported}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, dgettext("player", "Thanks! Your report was sent."))
     |> assign(:problem_details, nil)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp switch_episode(socket, nil), do: socket

  defp switch_episode(socket, %TvShowEpisode{} = episode),
    do: socket |> push_patch(to: Url.player_link(episode.videos), replace: true)

  # `start_at`, in seconds, starts there instead of where the User stopped, for Play at on the
  # Problem reports page
  defp start_player_session(socket, media_id, start_at) do
    actor = socket.assigns.current_user

    case Playbacks.start_session(media_id, load: @playback_session_fields, actor: actor) do
      {:ok, session} ->
        socket
        |> WatchClub.PubSub.subscribe_if_connected("video:#{media_id}")
        |> assign(:session, session)
        |> assign(
          :start_position_seconds,
          start_position_seconds(start_at, session.active_playback.media.video)
        )
        |> assign(:playback_error, false)

      {:error, error} ->
        Logger.error("Error starting new session: #{inspect(error)}")

        socket
        |> put_flash(:error, dgettext("player", "The video you were looking for does not exist"))
        |> push_navigate(to: ~p"/")
    end
  end

  defp start_new_playback_for_session(socket, media_id) do
    actor = socket.assigns.current_user

    case Playbacks.start_new_playback(socket.assigns.session, media_id,
           load: @playback_session_fields,
           actor: actor
         ) do
      {:ok, session} ->
        Phoenix.PubSub.unsubscribe(
          WatchClub.PubSub,
          "video:#{socket.assigns.session.active_playback.media_id}"
        )

        socket
        |> WatchClub.PubSub.subscribe_if_connected("video:#{media_id}")
        |> assign(:session, session)
        |> assign(:start_position_seconds, 0.0)
        |> assign(:playback_error, false)

      {:error, error} ->
        Logger.error("Error starting new playback: #{inspect(error)}")

        socket
        |> put_flash(:error, dgettext("player", "The video you were looking for does not exist"))
        |> push_navigate(to: ~p"/")
    end
  end

  defp start_position_seconds(start_at, video) do
    case start_at && Float.parse(start_at) do
      {seconds, ""} when seconds >= 0 -> seconds
      _ -> resume_position_seconds(video)
    end
  end

  # Only the Session's first Playback resumes where the user stopped; completed
  # or unwatched content restarts from the beginning.
  defp resume_position_seconds(%Video{} = video) do
    progress =
      case video do
        %Video{movie: %Movie{} = movie} -> movie.actor_progress
        %Video{tv_show_episode: %TvShowEpisode{} = episode} -> episode.actor_progress
      end

    if progress && !progress.completed, do: progress.position_seconds, else: 0.0
  end

  defp hls_master_playlist_url(%Playback{id: playback_id}),
    do: ~p"/player/hls/#{playback_id}/master.m3u8"

  defp thumbnails_url(%Playback{id: playback_id}),
    do: ~p"/player/thumbnails/#{playback_id}/thumbnails.vtt"
end
