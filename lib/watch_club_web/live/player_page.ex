defmodule WatchClubWeb.PlayerPage do
  @moduledoc """
  The Player: a Screen of the User's Playback Session. Its LiveView id names it as the Screen,
  so it stays the same Screen when it reconnects.

  It plays until another Screen takes the Playback Session. A TV that takes it opens the Remote
  here; another Player stops this one.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Live.Player.PlayerComponents

  alias WatchClubWeb.Live.Player.ReportProblemLive
  alias WatchClubWeb.TvSocket

  @playback_session_fields [
    current_playback: [
      media: [
        video:
          [
            :markers,
            :credits_start_seconds,
            :next_to_play,
            :previous_to_play,
            text_tracks: [:display_label, :language_code, :hls_supported?]
          ] ++ NowPlaying.video_fields()
      ]
    ]
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <main class="relative grid h-dvh place-items-center overflow-hidden bg-black text-white">
      <div
        :if={@session && !@playing_elsewhere?}
        id="watch-club-player"
        phx-hook="Player"
        data-videojs-src={~p"/assets/js/player_videojs.js"}
        data-playback-id={@session.current_playback.id}
        data-src={PlaybackPaths.master_playlist(@session.current_playback)}
        data-thumbnails-src={PlaybackPaths.thumbnails(@session.current_playback)}
        data-text-tracks={Jason.encode!(NowPlaying.text_track_files(@session.current_playback))}
        data-text-track-id={@session.current_playback.text_track_id}
        data-start-position={@start_at || @session.position_seconds}
        data-cast-app-id={Application.fetch_env!(:watch_club, :cast_app_id)}
        data-cast-emulator={cast_emulator()}
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
              <.skip_marker_buttons video={@session.current_playback.media.video} />
              <.up_next_button
                playback_id={@session.current_playback.id}
                video={@session.current_playback.media.video}
              />

              <media-controls
                phx-mounted={JS.ignore_attributes("*")}
                class="group/controls pointer-events-none absolute inset-0 z-30 flex flex-col justify-between bg-linear-to-t from-black/80 via-transparent to-black/80 opacity-0 transition-opacity data-visible:opacity-100 has-focus-visible:opacity-100"
              >
                <.controls_header video={@session.current_playback.media.video} />
                <.controls_center_row />
                <.controls_footer
                  playback_id={@session.current_playback.id}
                  video={@session.current_playback.media.video}
                />
              </media-controls>
            </media-container>
          </video-player>
        </media-i18n>

        <.cast_connecting_overlay :if={@casting_to} tv_name={@casting_to} />
      </div>

      <.player_load_error_overlay :if={@playback_error} administrator={@administrator} />

      <.playing_elsewhere_overlay :if={@playing_elsewhere?} />

      <.player_loader :if={!@session} class="absolute inset-0" />
    </main>

    <.live_component
      :if={@problem_details}
      module={ReportProblemLive}
      id="report-problem"
      details={@problem_details}
      category={if @playback_error, do: :player}
      current_user={@current_user}
      administrator={@administrator}
      on_close={JS.push("close_problem_report")}
    />

    <.flash flash={@flash} />
    """
  end

  # `WatchClubWeb.Hooks.PlaybackSession` subscribes it to the changes of the Playback Session.
  # The Problem Reports of this Player record its browser.
  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       session: nil,
       playback_error: false,
       playing_elsewhere?: false,
       casting_to: nil,
       reconnected?: connected?(socket) and get_connect_params(socket)["_mounts"] > 0,
       user_agent: get_connect_info(socket, :user_agent),
       problem_details: nil,
       administrator: Accounts.get_instance_administrator!(actor: socket.assigns.current_user)
     )}
  end

  # The Player plays once connected: its first render only shows the loader. Reconnecting isn't
  # playing again. `t`, in seconds, starts there instead of where the User stopped, for Play at on
  # the Problem reports page.
  @impl true
  def handle_params(%{"media_id" => media_id} = params, _uri, socket) do
    socket = assign(socket, :start_at, start_at(params["t"]))

    cond do
      !connected?(socket) ->
        {:noreply, socket}

      socket.assigns.reconnected? and !socket.assigns.session ->
        {:noreply, rejoin!(socket, media_id)}

      true ->
        {:noreply, play(socket, media_id)}
    end
  end

  @impl true
  def handle_event("player_ready", _params, socket) do
    {:noreply, socket |> assign(:playback_error, false)}
  end

  def handle_event("player_failed", _params, socket) do
    {:noreply, socket |> assign(:playback_error, true)}
  end

  # The hook paused the video and sends what the Player shows: nothing when the video never loaded
  def handle_event("report_problem", shown, socket) do
    details =
      shown
      |> Map.take(["position_seconds", "audio", "subtitles", "quality"])
      |> Map.merge(%{
        "playback_id" => socket.assigns.session.current_playback.id,
        "user_agent" => socket.assigns.user_agent
      })

    {:noreply, assign(socket, :problem_details, details)}
  end

  def handle_event("close_problem_report", _params, socket),
    do: {:noreply, assign(socket, :problem_details, nil)}

  # Reports about a Playback that's no longer current, or from a Player that's no longer the
  # Screen, fail. Its notification tells the second.
  def handle_event(
        "player_heartbeat",
        %{"playback_id" => playback_id, "position_seconds" => position, "paused" => paused?},
        socket
      ) do
    case Playbacks.heartbeat(socket.assigns.session, socket.id, playback_id, position, paused?,
           actor: socket.assigns.current_user
         ) do
      {:ok, _session} ->
        {:noreply, socket}

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} ->
        {:noreply, socket}
    end
  end

  def handle_event(
        "tracks_picked",
        %{
          "playback_id" => playback_id,
          "audio_track_id" => audio_track_id,
          "text_track_id" => text_track_id
        },
        socket
      ) do
    case Playbacks.pick_tracks(socket.assigns.session, playback_id, audio_track_id, text_track_id,
           actor: socket.assigns.current_user
         ) do
      {:ok, _session} ->
        {:noreply, socket}

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} ->
        {:noreply, socket}
    end
  end

  # From the "up next" prompt, or the end of the video
  def handle_event(event, %{"playback_id" => playback_id}, socket)
      when event in ["play_next_episode", "ended"],
      do: {:noreply, play_next(socket, playback_id)}

  def handle_event("play_previous_episode", _params, socket) do
    case socket.assigns.session.current_playback.media.video.previous_to_play do
      %{video: video} -> {:noreply, push_patch(socket, to: Url.player_link(video), replace: true)}
      nil -> {:noreply, socket}
    end
  end

  # Chrome connected to the TV: the TV takes the Playback Session with this token
  def handle_event("cast", %{"tv_name" => tv_name}, socket) do
    token = TvSocket.token(socket.assigns.session, tv_name, socket.id)
    :telemetry.execute([:watch_club, :cast], %{count: 1}, %{result: :started})
    {:reply, %{token: token}, assign(socket, :casting_to, tv_name)}
  end

  # Once per cast: the timeout and Cancel can cross
  def handle_event("cast_failed", _params, %{assigns: %{casting_to: nil}} = socket),
    do: {:noreply, socket}

  # The TV never took the Playback Session, often because it can't reach WatchClub
  def handle_event("cast_failed", %{"reason" => "timeout"}, socket) do
    :telemetry.execute([:watch_club, :cast], %{count: 1}, %{result: :failed})
    Logger.warning("Cast — The TV never joined", event: :cast_failed)

    {:noreply,
     socket
     |> assign(:casting_to, nil)
     |> put_flash(:error, cast_failed_message(socket.assigns))}
  end

  def handle_event("cast_failed", %{"reason" => "cancelled"}, socket) do
    :telemetry.execute([:watch_club, :cast], %{count: 1}, %{result: :cancelled})
    {:noreply, assign(socket, :casting_to, nil)}
  end

  @impl true
  def handle_info(
        %Notification{resource: Session, action: %{name: action}, data: %Session{} = session},
        socket
      )
      when action not in [:start, :heartbeat] do
    cond do
      session.id != socket.assigns.session.id or socket.assigns.playing_elsewhere? ->
        {:noreply, socket}

      # Nothing followed
      session.ended_at ->
        {:noreply, push_event(socket, "player:back", %{})}

      session.screen_id == socket.id ->
        {:noreply, socket}

      session.tv_name ->
        {:noreply, push_navigate(socket, to: ~p"/remote", replace: true)}

      true ->
        {:noreply, assign(socket, :playing_elsewhere?, true)}
    end
  end

  # The Markers of the Video playing are found in the background after its import
  def handle_info(%Notification{resource: Marker, data: %Marker{video_id: video_id}}, socket) do
    %{session: session, current_user: user} = socket.assigns

    if session.current_playback.media_id == video_id do
      video =
        Ash.load!(session.current_playback.media.video, [:markers, :credits_start_seconds],
          actor: user
        )

      {:noreply, assign(socket, :session, put_in(session.current_playback.media.video, video))}
    else
      {:noreply, socket}
    end
  end

  def handle_info({ReportProblemLive, :reported}, socket) do
    {:noreply,
     socket
     |> put_flash(
       :info,
       dgettext("player", "Thanks! We sent your report to %{admin}.",
         admin: socket.assigns.administrator.username
       )
     )
     |> assign(:problem_details, nil)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # Only the Instance Administrator can fix WatchClub's address, so only they get the likely cause
  defp cast_failed_message(%{current_user: %User{administrator?: true}}),
    do:
      dgettext(
        "player",
        "Couldn't play on the TV. It may not reach Watch Club: the TV needs an HTTPS address with a trusted certificate."
      )

  defp cast_failed_message(%{administrator: administrator}),
    do:
      dgettext(
        "player",
        "Couldn't play on the TV. Try again, and let %{admin} know if it keeps happening.",
        admin: administrator.username
      )

  defp start_at(t) do
    case t && Float.parse(t) do
      {seconds, ""} when seconds >= 0 -> seconds
      _none_or_invalid -> nil
    end
  end

  # While the Playback Session plays on a TV, it plays there and this page is its Remote
  defp play(socket, media_id) do
    case Playbacks.play(media_id, socket.id, actor: socket.assigns.current_user) do
      {:ok, %Session{tv_name: tv_name}} when tv_name != nil ->
        push_navigate(socket, to: ~p"/remote", replace: true)

      {:ok, session} ->
        show!(socket, session)

      {:error, error} ->
        Logger.error("Error playing Media: #{inspect(error)}")

        socket
        |> put_flash(:error, dgettext("player", "We couldn't find this video."))
        |> push_navigate(to: ~p"/")
    end
  end

  # Back in the Player after the connection dropped: it goes on as the Screen, or shows where the
  # Playback Session plays now. With none left, it plays again.
  defp rejoin!(socket, media_id) do
    case Playbacks.get_active_session!(actor: socket.assigns.current_user) do
      nil ->
        play(socket, media_id)

      %Session{screen_id: screen_id} = session when screen_id == socket.id ->
        show!(socket, session)

      %Session{tv_name: nil} = session ->
        assign(socket, session: session, playing_elsewhere?: true)

      %Session{} ->
        push_navigate(socket, to: ~p"/remote", replace: true)
    end
  end

  # When nothing follows, the Playback Session ends, which closes the Player. It fails once the
  # Playback isn't current: the click came late.
  defp play_next(socket, playback_id) do
    case Playbacks.play_next(socket.assigns.session, socket.id, playback_id,
           actor: socket.assigns.current_user
         ) do
      {:ok, %Session{ended_at: nil} = session} ->
        socket = show!(socket, session)
        media_id = socket.assigns.session.current_playback.media_id
        push_patch(socket, to: ~p"/play/#{media_id}", replace: true)

      {:ok, %Session{}} ->
        socket

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} ->
        socket
    end
  end

  defp show!(socket, session) do
    session = Ash.load!(session, @playback_session_fields, actor: socket.assigns.current_user)
    previous = socket.assigns.session && socket.assigns.session.current_playback.media_id

    if previous && previous != session.current_playback.media_id do
      Phoenix.PubSub.unsubscribe(WatchClub.PubSub, "video:#{previous}")
    end

    socket
    |> WatchClub.PubSub.subscribe_if_connected("video:#{session.current_playback.media_id}")
    |> assign(session: session, playback_error: false)
  end

  # In development, Chrome casts to a TV that the Cast emulator opens in a window
  if Application.compile_env(:watch_club, :dev_routes) do
    defp cast_emulator do
      Jason.encode!(%{
        scripts: [
          ~p"/dev/cast/emulator/presentation-polyfill.js",
          ~p"/dev/cast/emulator/cast-sender-emulator.js"
        ],
        receiver_url: ~p"/dev/cast/receiver"
      })
    end
  else
    defp cast_emulator, do: nil
  end
end
