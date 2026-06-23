defmodule WatchClubWeb.PlayerPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Player.SeekBar

  @impl true
  def render(assigns) do
    ~H"""
    <main class="fixed inset-0 h-dvh w-dvw overflow-hidden bg-black text-white">
      <section
        :if={is_nil(@session)}
        class="grid h-dvh w-dvw place-items-center bg-black px-page text-center"
      >
        <div :if={@player_error} class="max-w-readable space-y-related">
          <p class="text-lg font-semibold text-danger">
            {dgettext("player", "Error loading video")}
          </p>
          <.link
            navigate={~p"/"}
            class="inline-flex h-control-md items-center justify-center rounded-md border border-white/15 bg-white/10 px-group text-sm font-medium text-white hover:bg-white/20"
          >
            {dgettext("player", "Back home")}
          </.link>
        </div>

        <div :if={not @player_error} class="flex flex-col items-center gap-related text-white/80">
          <Lucideicons.loader_circle class="size-icon-xl animate-spin" />
          <div class="space-y-tight">
            <p class="text-lg font-semibold text-white">{dgettext("player", "Starting player…")}</p>
            <p class="text-sm text-white/60">
              {dgettext("player", "Preparing an HLS playback session.")}
            </p>
          </div>
        </div>
      </section>

      <section
        :if={@session}
        id="watch-club-player-shell"
        class="relative h-dvh w-dvw bg-black text-white"
      >
        <div
          id="watch-club-player"
          phx-hook="Player"
          phx-update="ignore"
          data-vidstack-src={~p"/assets/js/player_vidstack.js"}
          class="h-dvh w-dvw bg-black text-white"
        >
          <media-player
            id="watch-club-vidstack-player"
            data-player-media
            data-src={~p"/player/hls/#{@session.id}/master.m3u8"}
            title={playback_title(@session)}
            duration={@session.active_playback.media.video.duration_seconds}
            preload="metadata"
            playsinline
            data-controls="true"
            data-buffering="true"
            class="group/player relative block h-dvh w-dvw overflow-hidden bg-black text-white outline-none [&[data-started]:not([data-controls])]:cursor-none"
          >
            <media-provider class="absolute inset-0 block size-full overflow-hidden bg-black [&_video]:size-full [&_video]:bg-black [&_video]:object-contain [&_video]:outline-none">
            </media-provider>

            <media-gesture
              event="pointerup"
              action="toggle:paused"
              class="absolute inset-0 z-10 block"
              aria-hidden="true"
            >
            </media-gesture>

            <media-captions class="pointer-events-none absolute inset-x-4 bottom-32 z-20 mx-auto block max-w-[80%] text-center text-lg font-semibold text-white [text-shadow:0_2px_4px_rgb(0_0_0/0.85)] sm:text-2xl">
            </media-captions>

            <div
              class="pointer-events-none absolute inset-0 z-20 grid place-items-center opacity-0 transition-opacity duration-200 group-data-buffering/player:opacity-100"
              aria-hidden="true"
            >
              <div class="grid size-24 place-items-center rounded-full bg-black/55 backdrop-blur-sm">
                <Lucideicons.loader_circle class="size-14 animate-spin text-white/90" />
              </div>
            </div>

            <media-controls
              data-visible="true"
              hide-delay="3000"
              class="pointer-events-none absolute inset-0 z-30 flex flex-col justify-between bg-linear-to-trom-black/75 via-black/5 to-black/70 opacity-0 transition-opacity duration-200 data-visible:opacity-100"
            >
              <header
                class="pointer-events-auto flex w-full items-start justify-between gap-related px-4 pb-4 sm:px-8"
                style="padding-top: max(1rem, env(safe-area-inset-top));"
              >
                <button
                  type="button"
                  data-player-command="back"
                  class="inline-flex size-12 shrink-0 items-center justify-center rounded-md text-white outline-none hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-white/70"
                  aria-label={dgettext("player", "Back")}
                >
                  <Lucideicons.arrow_left class="size-8" />
                </button>

                <div class="min-w-0 flex-1 pt-1 text-center sm:pt-2">
                  <h1 class="truncate text-base font-semibold text-white sm:text-xl">
                    {playback_title(@session)}
                  </h1>
                  <p class="mx-auto mt-tight flex max-w-readable flex-wrap items-center justify-center gap-tight text-xs text-white/65 sm:text-sm">
                    <span>
                      {primary_video_track(@session).width}×{primary_video_track(@session).height}
                    </span>
                    <span aria-hidden="true">·</span>
                    <span>
                      {format_duration(@session.active_playback.media.video.duration_seconds)}
                    </span>
                    <span aria-hidden="true" class="hidden sm:inline">·</span>
                    <span class="hidden sm:inline">
                      {dgettext("player", "source %{codec}",
                        codec: primary_video_track(@session).codec
                      )}
                    </span>
                  </p>
                </div>

                <div class="flex shrink-0 items-center gap-tight">
                  <media-menu class="contents">
                    <media-menu-button
                      class="inline-flex size-10 items-center justify-center rounded-md text-white outline-none hover:bg-white/20 aria-disabled:pointer-events-none aria-disabled:opacity-40 data-focus:ring-2adata-focus:ring-white/70m:size-12"
                      aria-label={dgettext("player", "Quality")}
                    >
                      <Lucideicons.settings class="size-6 sm:size-7" />
                    </media-menu-button>

                    <media-menu-items class="fixed inset-x-4 bottom-4 z-50 block max-h-[70dvh] overflow-y-auto overscroll-contain rounded-xl border border-white/10 bg-black/95 p-group text-sm font-medium text-white shadow-overlay backdrop-blur-sm outline-none sm:absolute sm:inset-auto sm:top-20 sm:right-40 sm:w-64">
                      <p class="px-related pb-tight text-xs font-semibold uppercase tracking-wide text-white/55">
                        {dgettext("player", "Quality")}
                      </p>
                      <media-quality-radio-group auto-label={dgettext("player", "Auto")} hide-bitrate>
                        <template>
                          <media-radio class="group/radio flex w-full items-center rounded-md p-related text-left outline-none hover:bg-white/10 data-checked:bg-white/15ata-[focus]:ring-2 data-focus:ring-white/70">
                            <Lucideicons.check class="size-icon-sm opacity-0 group-data-checked/radio:opacity-100" />
                            <span data-part="label" class="ml-related" />
                          </media-radio>
                        </template>
                      </media-quality-radio-group>
                    </media-menu-items>
                  </media-menu>

                  <media-menu class="contents">
                    <media-menu-button
                      class="inline-flex size-10 items-center justify-center rounded-md text-white outline-none hover:bg-white/20 aria-disabled:pointer-events-none aria-disabled:opacity-40 data-focus:ring-2 data-focus:ring-white/70 sm:size-12"
                      aria-label={dgettext("player", "Audio")}
                    >
                      <Lucideicons.languages class="size-6 sm:size-7" />
                    </media-menu-button>

                    <media-menu-items class="fixed inset-x-4 bottom-4 z-50 block max-h-[70dvh] overflow-y-auto overscroll-contain rounded-xl border border-white/10 bg-black/95 p-group text-sm font-medium text-white shadow-overlay backdrop-blur-sm outline-none sm:absolute sm:inset-auto sm:top-20 sm:right-28 sm:w-72">
                      <p class="px-related pb-tight text-xs font-semibold uppercase tracking-wide text-white/55">
                        {dgettext("player", "Audio")}
                      </p>
                      <media-audio-radio-group>
                        <template>
                          <media-radio class="group/radio flex w-full items-center rounded-md p-related text-left outline-none hover:bg-white/10 data-checked:bg-white/15 data-focus:ring-2 data-focus:ring-white/70">
                            <Lucideicons.check class="size-icon-sm opacity-0 group-data-checked/radio:opacity-100" />
                            <span data-part="label" class="ml-related"></span>
                          </media-radio>
                        </template>
                      </media-audio-radio-group>
                    </media-menu-items>
                  </media-menu>

                  <media-menu class="contents">
                    <media-menu-button
                      class="inline-flex size-10 items-center justify-center rounded-md text-white outline-none hover:bg-white/20 aria-disabled:pointer-events-none aria-disabled:opacity-40 data-focus:ring-2 data-focus:ring-white/70 sm:size-12"
                      aria-label={dgettext("player", "Subtitles")}
                    >
                      <Lucideicons.captions class="size-6 sm:size-7" />
                    </media-menu-button>

                    <media-menu-items class="fixed inset-x-4 bottom-4 z-50 block max-h-[70dvh] overflow-y-auto overscroll-contain rounded-xl border border-white/10 bg-black/95 p-group text-sm font-medium text-white shadow-overlay backdrop-blur-sm outline-none sm:absolute sm:inset-auto sm:top-20 sm:right-16 sm:w-72">
                      <p class="px-related pb-tight text-xs font-semibold uppercase tracking-wide text-white/55">
                        {dgettext("player", "Subtitles")}
                      </p>
                      <media-captions-radio-group off-label={dgettext("player", "Off")}>
                        <template>
                          <media-radio class="group/radio flex w-full items-center rounded-md p-related text-left outline-none hover:bg-white/10 data-checked:bg-white/15 data-focus:ring-2 data-focus:ring-white/70">
                            <Lucideicons.check class="size-icon-sm opacity-0 group-data-checked/radio:opacity-100" />
                            <span data-part="label" class="ml-related"></span>
                          </media-radio>
                        </template>
                      </media-captions-radio-group>
                    </media-menu-items>
                  </media-menu>

                  <media-mute-button
                    class="group/mute inline-flex size-10 items-center justify-center rounded-md text-white outline-none hover:bg-white/20 data-focus:ring-2 data-focus:ring-white/70 sm:size-12"
                    aria-label={dgettext("player", "Mute")}
                  >
                    <Lucideicons.volume_2 class="size-6 group-data-muted/mute:hidden sm:size-7" />
                    <Lucideicons.volume_x class="hidden size-6 group-data-muted/mute:block sm:size-7" />
                  </media-mute-button>

                  <media-fullscreen-button
                    target="media"
                    class="group/fullscreen inline-flex size-10 items-center justify-center rounded-md text-white outline-none hover:bg-white/20 data-focus:ring-2 data-focus:ring-white/70 sm:size-12"
                    aria-label={dgettext("player", "Fullscreen")}
                  >
                    <Lucideicons.maximize class="size-6 group-data-active/fullscreen:hidden sm:size-7" />
                    <Lucideicons.minimize class="hidden size-6 group-data-active/fullscreen:block sm:size-7" />
                  </media-fullscreen-button>
                </div>
              </header>

              <div class="pointer-events-none flex flex-1 items-center justify-center px-page">
                <div class="pointer-events-auto flex items-center justify-center gap-related opacity-90 transition-opacity duration-200 group-data-buffering/player:opacity-0">
                  <media-seek-button
                    seconds="-10"
                    class="inline-flex size-20 items-center justify-center rounded-md text-white outline-none hover:bg-white/20 data-focus:ring-2 data-focus:ring-white/70 sm:size-24"
                    aria-label={dgettext("player", "Seek backward 10 seconds")}
                  >
                    <Lucideicons.rotate_ccw class="size-12 sm:size-16" />
                    <span class="absolute mt-1 text-xs font-bold">10</span>
                  </media-seek-button>

                  <media-play-button
                    data-paused="true"
                    class="group/play inline-flex size-24 items-center justify-center rounded-md text-white outline-none hover:bg-white/20 data-focus:ring-2 data-focus:ring-white/70 sm:size-28"
                    aria-label={dgettext("player", "Play or pause")}
                  >
                    <Lucideicons.play class="hidden size-20 group-data-paused/play:block sm:size-24" />
                    <Lucideicons.pause class="size-20 group-data-paused/play:hiddenm:size-24" />
                  </media-play-button>

                  <media-seek-button
                    seconds="10"
                    class="inline-flex size-20 items-center justify-center rounded-md text-white outline-none hover:bg-white/20 data-focus:ring-2 data-focus:ring-white/70 sm:size-24"
                    aria-label={dgettext("player", "Seek forward 10 seconds")}
                  >
                    <Lucideicons.rotate_cw class="size-12 sm:size-16" />
                    <span class="absolute mt-1 text-xs font-bold">10</span>
                  </media-seek-button>
                </div>
              </div>

              <footer
                class="pointer-events-auto flex w-full flex-col gap-related px-4 pt-4 sm:px-8"
                style="padding-bottom: max(1rem, env(safe-area-inset-bottom));"
              >
                <.seek_bar thumbnails={~p"/player/thumbnails/#{@session.id}/thumbnails.vtt"} />

                <div class="relative flex min-h-control-sm items-center justify-center text-sm font-medium text-white/90 tabular-nums">
                  <div class="flex items-center justify-center gap-tight">
                    <media-time type="current">0:00</media-time>
                    <span class="text-white/60">/</span>
                    <media-time type="duration">
                      {format_duration(@session.active_playback.media.video.duration_seconds)}
                    </media-time>
                  </div>

                  <button
                    type="button"
                    data-player-next
                    hidden
                    class="absolute right-0 inline-flex h-control-sm items-center gap-tight rounded-md px-related text-sm font-medium text-white hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-white/70"
                  >
                    <Lucideicons.skip_forward class="size-icon" />
                    <span class="hidden sm:inline">{dgettext("player", "Next episode")}</span>
                  </button>
                </div>
              </footer>
            </media-controls>

            <button
              type="button"
              data-player-skip-segment
              hidden
              class="absolute right-4 bottom-28 z-40 inline-flex items-center gap-tight overflow-hidden rounded-md border border-white/15 bg-black/80 px-group py-related text-sm font-medium text-white shadow-overlay backdrop-blur-sm hover:bg-black/90 focus-visible:ring-2 focus-visible:ring-white/70 sm:right-8 sm:bottom-32"
            >
              <Lucideicons.skip_forward class="size-icon" />
              <span data-player-skip-label>{dgettext("player", "Skip")}</span>
            </button>

            <media-announcer></media-announcer>
          </media-player>
        </div>

        <div
          :if={@playback_error}
          id="watch-club-player-error"
          class="pointer-events-none absolute inset-0 z-50 grid place-items-center bg-scrim px-page text-center"
          role="alert"
          aria-live="assertive"
        >
          <div class="max-w-readable rounded-xl border border-border bg-surface-overlay p-group text-text shadow-overlay">
            <p class="text-lg font-semibold">
              {dgettext("player", "Error loading video")}
            </p>
          </div>
        </div>
      </section>
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
      Process.flag(:trap_exit, true)
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

  @impl true
  def terminate(_reason, socket) do
    stop_session(socket.assigns[:current_user], socket.assigns[:session], nil)
    :ok
  end

  defp start_player_session(socket, media_id) do
    actor = socket.assigns.current_user

    case Playbacks.start_session(media_id, actor: actor) do
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

  defp primary_video_track(session), do: session.active_playback.media.video.default_video_track

  defp stop_session(actor, %{} = session, position) when not is_nil(actor) do
    case Playbacks.close_session(session, %{position_seconds: position}, actor: actor) do
      {:ok, _session} -> %{ok: true}
      {:error, %Ash.Error.Forbidden{}} -> %{ok: true}
      {:error, reason} -> %{ok: false, error: inspect(reason)}
    end
  end

  defp stop_session(_actor, _session, _position), do: %{ok: true}

  defp format_duration(duration) do
    total = duration |> trunc() |> max(0)
    hours = div(total, 3600)
    minutes = total |> rem(3600) |> div(60)
    seconds = total |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")

    if hours > 0 do
      "#{hours}:#{Integer.to_string(minutes) |> String.pad_leading(2, "0")}:#{seconds}"
    else
      "#{minutes}:#{seconds}"
    end
  end
end
