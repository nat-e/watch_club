defmodule WatchClubWeb.PlayerPage do
  use WatchClubWeb, :live_view

  alias WatchClub.Playback.HlsSession

  @impl true
  def render(assigns) do
    ~H"""
    <main class="fixed inset-0 h-dvh w-dvw overflow-hidden bg-black text-white">
      <section
        :if={is_nil(@player_session)}
        class="grid h-dvh w-dvw place-items-center bg-black px-page text-center"
      >
        <div :if={@player_error} class="max-w-readable space-y-related">
          <p class="text-lg font-semibold text-danger">
            {dgettext("player", "Could not start player session")}
          </p>
          <p class="text-sm text-white/65">{@player_error}</p>
          <.link
            navigate={~p"/"}
            class="inline-flex h-control-md items-center justify-center rounded-control border border-white/15 bg-white/10 px-group text-sm font-medium text-white hover:bg-white/20"
          >
            {dgettext("player", "Back home")}
          </.link>
        </div>

        <div :if={is_nil(@player_error)} class="flex flex-col items-center gap-related text-white/80">
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
        :if={@player_session}
        id="watch-club-player"
        phx-hook="Player"
        phx-update="ignore"
        data-session={Jason.encode!(@player_session)}
        data-hls-src={~p"/assets/js/player_hls.js"}
        data-controls="visible"
        data-playing="false"
        data-buffering="true"
        data-muted="false"
        data-menu="closed"
        data-fullscreen="false"
        data-ended="false"
        class="group relative h-dvh w-dvw overflow-hidden bg-black text-white data-[controls=hidden]:cursor-none"
      >
        <video
          id="player-video"
          data-player-video
          class="absolute inset-0 size-full bg-black object-contain"
          playsinline
          preload="metadata"
        >
        </video>

        <div data-player-surface class="absolute inset-0 z-10" aria-hidden="true"></div>

        <div
          class="pointer-events-none absolute inset-0 z-20 grid place-items-center opacity-0 transition-opacity duration-200 group-data-[buffering=true]:opacity-100"
          aria-hidden="true"
        >
          <div class="grid size-24 place-items-center rounded-full bg-black/55 backdrop-blur-sm">
            <Lucideicons.loader_circle class="size-14 animate-spin text-white/90" />
          </div>
        </div>

        <div
          data-player-controls
          class="pointer-events-none absolute inset-0 z-30 flex flex-col justify-between bg-gradient-to-t from-black/75 via-black/5 to-black/70 opacity-100 transition-opacity duration-200 group-data-[controls=hidden]:opacity-0"
        >
          <header
            class="pointer-events-auto flex w-full items-start justify-between gap-related px-4 pb-4 sm:px-8"
            style="padding-top: max(1rem, env(safe-area-inset-top));"
          >
            <button
              type="button"
              data-player-command="back"
              class="inline-flex size-12 shrink-0 items-center justify-center rounded-control text-white outline-none hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-white/70"
              aria-label={dgettext("player", "Back")}
            >
              <Lucideicons.arrow_left class="size-8" />
            </button>

            <div class="min-w-0 flex-1 pt-1 text-center sm:pt-2">
              <h1 class="truncate text-base font-semibold text-white sm:text-xl">
                {@player_session.title}
              </h1>
              <p class="mx-auto mt-tight flex max-w-readable flex-wrap items-center justify-center gap-tight text-xs text-white/65 sm:text-sm">
                <span>
                  {@player_session.video.width}×{@player_session.video.height}
                </span>
                <span aria-hidden="true">·</span>
                <span>{format_duration(@player_session.duration)}</span>
                <span aria-hidden="true" class="hidden sm:inline">·</span>
                <span class="hidden sm:inline">
                  {dgettext("player", "source %{codec}", codec: @player_session.video.codec)}
                </span>
                <span data-player-status class="basis-full text-white/55 sm:basis-auto">
                  {dgettext("player", "Starting…")}
                </span>
              </p>
            </div>

            <div class="flex shrink-0 items-center gap-tight">
              <button
                type="button"
                data-player-menu-button="quality"
                class="inline-flex size-10 items-center justify-center rounded-control text-white outline-none hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-white/70 sm:size-12"
                aria-label={dgettext("player", "Quality")}
                aria-haspopup="menu"
              >
                <Lucideicons.settings class="size-6 sm:size-7" />
              </button>

              <button
                type="button"
                data-player-menu-button="audio"
                disabled={length(@player_session.audio_tracks) <= 1}
                class="inline-flex size-10 items-center justify-center rounded-control text-white outline-none hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-white/70 disabled:pointer-events-none disabled:opacity-40 sm:size-12"
                aria-label={dgettext("player", "Audio")}
                aria-haspopup="menu"
              >
                <Lucideicons.languages class="size-6 sm:size-7" />
              </button>

              <button
                type="button"
                data-player-menu-button="subtitles"
                disabled={Enum.empty?(@player_session.subtitle_tracks)}
                class="inline-flex size-10 items-center justify-center rounded-control text-white outline-none hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-white/70 disabled:pointer-events-none disabled:opacity-40 sm:size-12"
                aria-label={dgettext("player", "Subtitles")}
                aria-haspopup="menu"
              >
                <Lucideicons.captions class="size-6 sm:size-7" />
              </button>

              <button
                type="button"
                data-player-command="mute-toggle"
                class="inline-flex size-10 items-center justify-center rounded-control text-white outline-none hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-white/70 sm:size-12"
                aria-label={dgettext("player", "Mute")}
              >
                <Lucideicons.volume_2 data-player-unmuted-icon class="size-6 sm:size-7" />
                <Lucideicons.volume_x data-player-muted-icon class="hidden size-6 sm:size-7" />
              </button>

              <button
                type="button"
                data-player-command="fullscreen-toggle"
                class="inline-flex size-10 items-center justify-center rounded-control text-white outline-none hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-white/70 sm:size-12"
                aria-label={dgettext("player", "Fullscreen")}
              >
                <Lucideicons.maximize data-player-fullscreen-enter-icon class="size-6 sm:size-7" />
                <Lucideicons.minimize
                  data-player-fullscreen-exit-icon
                  class="hidden size-6 sm:size-7"
                />
              </button>
            </div>
          </header>

          <div class="pointer-events-none flex flex-1 items-center justify-center px-page">
            <div class="pointer-events-auto flex items-center justify-center gap-related opacity-90 transition-opacity duration-200 group-data-[buffering=true]:opacity-0">
              <button
                type="button"
                data-player-command="seek-back"
                data-seconds="-10"
                class="inline-flex size-20 items-center justify-center rounded-control text-white outline-none hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-white/70 sm:size-24"
                aria-label={dgettext("player", "Seek backward 10 seconds")}
              >
                <Lucideicons.rotate_ccw class="size-12 sm:size-16" />
                <span class="absolute mt-1 text-xs font-bold">10</span>
              </button>

              <button
                type="button"
                data-player-command="play-toggle"
                class="inline-flex size-24 items-center justify-center rounded-control text-white outline-none hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-white/70 sm:size-28"
                aria-label={dgettext("player", "Play or pause")}
              >
                <Lucideicons.play data-player-play-icon class="size-20 sm:size-24" />
                <Lucideicons.pause data-player-pause-icon class="hidden size-20 sm:size-24" />
              </button>

              <button
                type="button"
                data-player-command="seek-forward"
                data-seconds="10"
                class="inline-flex size-20 items-center justify-center rounded-control text-white outline-none hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-white/70 sm:size-24"
                aria-label={dgettext("player", "Seek forward 10 seconds")}
              >
                <Lucideicons.rotate_cw class="size-12 sm:size-16" />
                <span class="absolute mt-1 text-xs font-bold">10</span>
              </button>
            </div>
          </div>

          <footer
            class="pointer-events-auto flex w-full flex-col gap-related px-4 pt-4 sm:px-8"
            style="padding-bottom: max(1rem, env(safe-area-inset-bottom));"
          >
            <div
              data-player-timeline
              role="slider"
              tabindex="0"
              aria-label={dgettext("player", "Seek")}
              aria-valuemin="0"
              aria-valuemax={trunc(@player_session.duration)}
              aria-valuenow="0"
              class="group/timeline relative h-10 w-full cursor-pointer touch-none outline-none"
            >
              <div class="absolute top-1/2 h-[5px] w-full -translate-y-1/2 rounded-full bg-white/30 group-focus-visible/timeline:ring-2 group-focus-visible/timeline:ring-white/70">
                <div
                  data-player-buffered-bar
                  class="absolute h-full rounded-full bg-white/45"
                  style="width: 0%;"
                >
                </div>
                <div
                  data-player-progress-bar
                  class="absolute h-full rounded-full bg-primary"
                  style="width: 0%;"
                >
                </div>
              </div>
              <div
                data-player-timeline-thumb
                class="absolute top-1/2 size-4 -translate-x-1/2 -translate-y-1/2 rounded-full bg-white opacity-90 shadow-overlay ring-white/40 transition-transform group-hover/timeline:scale-125 group-data-[dragging=true]/timeline:scale-125 group-data-[dragging=true]/timeline:ring-4"
                style="left: 0%;"
              >
              </div>
            </div>

            <div class="relative flex min-h-control-sm items-center justify-center text-sm font-medium text-white/90 tabular-nums">
              <div class="flex items-center justify-center gap-tight">
                <span data-player-current-time>0:00</span>
                <span class="text-white/60">/</span>
                <span data-player-duration>{format_duration(@player_session.duration)}</span>
              </div>

              <button
                type="button"
                data-player-next
                hidden
                class="absolute right-0 inline-flex h-control-sm items-center gap-tight rounded-control px-related text-sm font-medium text-white hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-white/70"
              >
                <Lucideicons.skip_forward class="size-icon" />
                <span class="hidden sm:inline">{dgettext("player", "Next episode")}</span>
              </button>
            </div>
          </footer>
        </div>

        <button
          type="button"
          data-player-skip-segment
          hidden
          class="absolute right-4 bottom-28 z-40 inline-flex items-center gap-tight overflow-hidden rounded-control border border-white/15 bg-black/80 px-group py-related text-sm font-medium text-white shadow-overlay backdrop-blur-sm hover:bg-black/90 focus-visible:ring-2 focus-visible:ring-white/70 sm:right-8 sm:bottom-32"
        >
          <Lucideicons.skip_forward class="size-icon" />
          <span data-player-skip-label>{dgettext("player", "Skip")}</span>
        </button>

        <div
          data-player-menu-panel="quality"
          hidden
          class="fixed inset-x-4 bottom-4 z-50 max-h-[70dvh] overflow-y-auto overscroll-contain rounded-card border border-white/10 bg-black/95 p-group text-sm font-medium text-white shadow-overlay backdrop-blur-sm outline-none sm:absolute sm:inset-auto sm:top-20 sm:right-40 sm:w-64"
          role="menu"
          aria-label={dgettext("player", "Quality")}
        >
          <p class="px-related pb-tight text-xs font-semibold uppercase tracking-wide text-white/55">
            {dgettext("player", "Quality")}
          </p>
          <button
            type="button"
            data-player-quality-option="auto"
            data-selected="true"
            class="group flex w-full items-center rounded-control p-related text-left outline-none hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-white/70 data-[selected=true]:bg-white/15"
            role="menuitemradio"
            aria-checked="true"
          >
            <Lucideicons.check class="size-icon-sm opacity-0 group-data-[selected=true]:opacity-100" />
            <span class="ml-related">{dgettext("player", "Auto")}</span>
          </button>
          <button
            :for={quality <- @player_session.qualities}
            type="button"
            data-player-quality-option={quality.id}
            data-quality-width={quality.width}
            data-quality-height={quality.height}
            data-selected="false"
            class="group flex w-full items-center rounded-control p-related text-left outline-none hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-white/70 data-[selected=true]:bg-white/15"
            role="menuitemradio"
            aria-checked="false"
          >
            <Lucideicons.check class="size-icon-sm opacity-0 group-data-[selected=true]:opacity-100" />
            <span class="ml-related">{quality.label}</span>
          </button>
        </div>

        <div
          data-player-menu-panel="audio"
          hidden
          class="fixed inset-x-4 bottom-4 z-50 max-h-[70dvh] overflow-y-auto overscroll-contain rounded-card border border-white/10 bg-black/95 p-group text-sm font-medium text-white shadow-overlay backdrop-blur-sm outline-none sm:absolute sm:inset-auto sm:top-20 sm:right-28 sm:w-72"
          role="menu"
          aria-label={dgettext("player", "Audio")}
        >
          <p class="px-related pb-tight text-xs font-semibold uppercase tracking-wide text-white/55">
            {dgettext("player", "Audio")}
          </p>
          <button
            :for={{track, index} <- Enum.with_index(@player_session.audio_tracks)}
            type="button"
            data-player-audio-option={index}
            data-selected={if track.default?, do: "true", else: "false"}
            class="group flex w-full items-center rounded-control p-related text-left outline-none hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-white/70 data-[selected=true]:bg-white/15"
            role="menuitemradio"
            aria-checked={if track.default?, do: "true", else: "false"}
          >
            <Lucideicons.check class="size-icon-sm opacity-0 group-data-[selected=true]:opacity-100" />
            <span class="ml-related">{track.label}</span>
          </button>
        </div>

        <div
          data-player-menu-panel="subtitles"
          hidden
          class="fixed inset-x-4 bottom-4 z-50 max-h-[70dvh] overflow-y-auto overscroll-contain rounded-card border border-white/10 bg-black/95 p-group text-sm font-medium text-white shadow-overlay backdrop-blur-sm outline-none sm:absolute sm:inset-auto sm:top-20 sm:right-16 sm:w-72"
          role="menu"
          aria-label={dgettext("player", "Subtitles")}
        >
          <p class="px-related pb-tight text-xs font-semibold uppercase tracking-wide text-white/55">
            {dgettext("player", "Subtitles")}
          </p>
          <button
            type="button"
            data-player-subtitle-option="-1"
            data-selected="true"
            class="group flex w-full items-center rounded-control p-related text-left outline-none hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-white/70 data-[selected=true]:bg-white/15"
            role="menuitemradio"
            aria-checked="true"
          >
            <Lucideicons.check class="size-icon-sm opacity-0 group-data-[selected=true]:opacity-100" />
            <span class="ml-related">{dgettext("player", "Off")}</span>
          </button>
          <button
            :for={{track, index} <- Enum.with_index(@player_session.subtitle_tracks)}
            type="button"
            data-player-subtitle-option={index}
            data-selected="false"
            class="group flex w-full items-center rounded-control p-related text-left outline-none hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-white/70 data-[selected=true]:bg-white/15"
            role="menuitemradio"
            aria-checked="false"
          >
            <Lucideicons.check class="size-icon-sm opacity-0 group-data-[selected=true]:opacity-100" />
            <span class="ml-related">{track.label}</span>
          </button>
        </div>
      </section>
    </main>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "WatchClub Player")
      |> assign(:player_session, nil)
      |> assign(:player_error, nil)

    if connected?(socket) do
      Process.flag(:trap_exit, true)
      start_player_session(socket)
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("player_stop", _params, socket) do
    {:reply, stop_player_session(socket.assigns.player_session), socket}
  end

  @impl true
  def terminate(_reason, socket) do
    stop_player_session(socket.assigns[:player_session])
    :ok
  end

  defp start_player_session(socket) do
    case HlsSession.start_session() do
      {:ok, session} -> {:ok, assign(socket, :player_session, session)}
      {:error, reason} -> {:ok, assign(socket, :player_error, inspect(reason))}
    end
  end

  defp stop_player_session(%{id: session_id}) do
    case HlsSession.stop(session_id) do
      :ok -> %{ok: true}
      {:error, :not_found} -> %{ok: true}
      {:error, reason} -> %{ok: false, error: inspect(reason)}
    end
  end

  defp stop_player_session(_session), do: %{ok: true}

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
