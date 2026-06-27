defmodule WatchClubWeb.PlayerPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Live.Player.PlayerComponents

  @playback_session_fields [
    active_playback: [
      media: [
        video: [
          movie: [:best_localization],
          tv_show_episode: [
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
    <main class="fixed inset-0 grid place-items-center overflow-hidden bg-black text-white">
      <div
        :if={@session}
        id="watch-club-player"
        phx-hook="Player"
        data-vidstack-src={~p"/assets/js/player_vidstack.js"}
        class="size-full"
      >
        <media-player
          id="watch-club-vidstack-player"
          data-player-media
          data-src={hls_master_playlist_url(@session.active_playback)}
          duration={@session.active_playback.media.video.duration_seconds}
          preload="metadata"
          playsinline
          class="group/player relative block size-full overflow-hidden bg-black outline-none [&[data-started]:not([data-controls])]:cursor-none"
        >
          <media-provider
            id="watch-club-media-provider"
            phx-update="ignore"
            class="absolute inset-0 block [&_video]:size-full [&_video]:object-contain"
          />

          <%!-- On touch, a tap toggles play/pause only while the controls are showing
                (data-controls). When they're hidden the gesture is display:none, so its
                hit-test misses, the tap falls through to Vidstack's native control reveal
                (with auto-hide), and nothing is paused. Hover pointers always pause. --%>
          <media-gesture
            event="pointerup"
            action="toggle:paused"
            class="absolute inset-0 z-10 hidden group-data-controls/player:block [@media(hover:hover)]:block"
            aria-hidden="true"
          />

          <media-captions
            id="watch-club-media-captions"
            phx-update="ignore"
            class="pointer-events-none absolute inset-x-4 bottom-32 z-20 mx-auto block max-w-[80%] text-center text-lg font-semibold [text-shadow:0_2px_4px_rgb(0_0_0/0.85)] sm:text-2xl"
          />

          <.player_loader class="absolute inset-0 z-20 opacity-0 transition-opacity group-data-buffering/player:opacity-100" />

          <media-controls
            data-visible="true"
            hide-delay="3000"
            class="pointer-events-none absolute inset-0 z-30 flex flex-col justify-between bg-linear-to-t from-black/70 via-transparent to-black/70 opacity-0 transition-opacity data-visible:opacity-100"
          >
            <.controls_header video={@session.active_playback.media.video} />
            <.controls_center_row />
            <.controls_footer
              playback_id={@session.active_playback.id}
              video={@session.active_playback.media.video}
            />
          </media-controls>

          <.up_next_button video={@session.active_playback.media.video} />

          <media-announcer />
        </media-player>
      </div>

      <.player_load_error_overlay :if={@playback_error} />

      <.player_loader :if={!@session} class="absolute inset-0" />
    </main>
    """
  end

  @impl true
  def handle_params(%{"media_id" => media_id}, _uri, socket) do
    cond do
      # Don't load the player on the initial server-side render
      !connected?(socket) ->
        {:noreply, socket |> assign(:session, nil) |> assign(:playback_error, false)}

      # Initial player load, create a session
      is_nil(socket.assigns[:session]) ->
        {:noreply, socket |> start_player_session(media_id)}

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

  def handle_event("player_heartbeat", params, socket) do
    # Best effort, don't crash the process if heartbeat fails
    Playbacks.heartbeat_session(
      socket.assigns.session,
      %{position_seconds: params["position_seconds"]},
      actor: socket.assigns.current_user
    )

    {:noreply, socket}
  end

  def handle_event("play_next_episode", _params, socket) do
    video = socket.assigns.session.active_playback.media.video
    next_episode = video.tv_show_episode && video.tv_show_episode.next_episode

    {:noreply, socket |> switch_episode(next_episode)}
  end

  def handle_event("play_previous_episode", _params, socket) do
    video = socket.assigns.session.active_playback.media.video
    previous_episode = video.tv_show_episode && video.tv_show_episode.previous_episode

    {:noreply, socket |> switch_episode(previous_episode)}
  end

  defp switch_episode(socket, nil), do: socket

  defp switch_episode(socket, %TvShowEpisode{} = episode),
    do: socket |> push_patch(to: Url.player_link(episode.videos), replace: true)

  defp start_player_session(socket, media_id) do
    actor = socket.assigns.current_user

    case Playbacks.start_session(media_id, load: @playback_session_fields, actor: actor) do
      {:ok, session} ->
        socket |> assign(:session, session) |> assign(:playback_error, false)

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
        socket
        |> assign(:session, session)
        |> assign(:playback_error, false)
        # We manually push an event to the JS Hook to reload the video since Vidstack's media provider is phx-update="ignore"
        # It has to be the case, otherwise Morphdom deletes the <video> element injected at runtime by Vidstack
        |> push_event("player:load_video", %{
          src: hls_master_playlist_url(session.active_playback)
        })

      {:error, error} ->
        Logger.error("Error starting new playback: #{inspect(error)}")

        socket
        |> put_flash(:error, dgettext("player", "The video you were looking for does not exist"))
        |> push_navigate(to: ~p"/")
    end
  end

  defp hls_master_playlist_url(%Playback{id: playback_id}),
    do: ~p"/player/hls/#{playback_id}/master.m3u8"
end
