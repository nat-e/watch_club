defmodule WatchClubWeb.Live.Player.PlayerComponents do
  use WatchClubWeb, :component

  attr :label, :string, required: true, doc: "Menu title and trigger aria-label."
  slot :icon, required: true, doc: "Trigger icon."
  slot :inner_block, required: true, doc: "The Vidstack radio group for this menu."

  @doc "A control-bar dropdown wrapping one of Vidstack's radio groups."
  def player_menu(assigns) do
    ~H"""
    <media-menu class="contents">
      <media-menu-button
        class={media_menu_button_style()}
        aria-label={@label}
      >
        {render_slot(@icon)}
      </media-menu-button>

      <media-menu-items class="fixed inset-x-4 bottom-4 z-50 block max-h-[70dvh] overflow-y-auto overscroll-contain rounded-xl border border-white/10 bg-black/95 p-group text-sm font-medium text-white shadow-overlay backdrop-blur-sm outline-none sm:absolute sm:inset-auto sm:top-20 sm:right-16 sm:w-72">
        <p class="px-related pb-tight text-xs font-semibold uppercase tracking-wide text-white/55">
          {@label}
        </p>
        {render_slot(@inner_block)}
      </media-menu-items>
    </media-menu>
    """
  end

  @doc "A single option rendered inside a radio group's <template>."
  def player_radio(assigns) do
    ~H"""
    <media-radio class="group/radio flex w-full items-center gap-related rounded-md p-related text-left outline-none hover:bg-white/10 data-checked:bg-white/15 data-focus:ring-2 data-focus:ring-white/70">
      <Lucideicons.check class="size-icon-sm opacity-0 group-data-checked/radio:opacity-100" />
      <span data-part="label"></span>
    </media-radio>
    """
  end

  attr :thumbnails, :string, required: true, doc: "URL of the trickplay WebVTT manifest."

  def seek_bar(assigns) do
    ~H"""
    <media-time-slider
      key-step="10"
      shift-key-multiplier="1"
      aria-label={dgettext("player", "Seek")}
      class="group/timeline relative block h-10 w-full cursor-pointer touch-none outline-none"
    >
      <media-slider-preview class="pointer-events-none absolute bottom-full mb-3 flex flex-col items-center gap-tight opacity-0 transition-opacity duration-200 data-visible:opacity-100">
        <%!-- width/height come from Vidstack's per-cue --thumbnail-* vars; contain + overflow
              clip the sprite sheet to a single tile, min/max scale it to a preview size. --%>
        <media-slider-thumbnail
          src={@thumbnails}
          class="block overflow-hidden rounded-md border border-white/15 bg-black shadow-overlay data-hidden:hidden"
          style="width: var(--thumbnail-width); height: var(--thumbnail-height); contain: strict; min-width: 120px; min-height: 80px; max-width: 220px; max-height: 160px;"
        >
        </media-slider-thumbnail>
        <media-slider-value class="rounded-md bg-black/80 px-related py-tight text-xs font-medium text-white tabular-nums">
        </media-slider-value>
      </media-slider-preview>

      <div class="absolute top-1/2 h-[5px] w-full -translate-y-1/2 rounded-full bg-white/30 group-data-focus/timeline:ring-2 group-data-focus/timeline:ring-white/70">
        <div
          class="absolute h-full rounded-full bg-white/45"
          style="width: var(--slider-progress, 0%);"
        >
        </div>
        <div
          class="absolute h-full rounded-full bg-primary"
          style="width: var(--slider-fill, 0%);"
        >
        </div>
      </div>
      <div
        class="absolute top-1/2 size-4 -translate-x-1/2 -translate-y-1/2 rounded-full bg-white opacity-90 shadow-overlay ring-white/40 transition-transform group-hover/timeline:scale-125 group-data-active/timeline:scale-125 group-data-dragging/timeline:ring-4"
        style="left: var(--slider-fill, 0%);"
      >
      </div>
    </media-time-slider>
    """
  end

  attr :video, Video, required: true

  def controls_header(assigns) do
    ~H"""
    <header class="flex h-24 items-center gap-related px-related pointer-events-auto">
      <button
        type="button"
        data-player-command="back"
        class={media_menu_button_style()}
        aria-label={dgettext("player", "Back")}
      >
        <Lucideicons.arrow_left />
      </button>

      <div class="min-w-0 flex-1">
        <h1 class="truncate text-base font-semibold sm:text-xl">
          {header_title(@video)}
        </h1>
      </div>

      <div class="flex shrink-0 items-center gap-tight">
        <.player_menu label={dgettext("player", "Quality")}>
          <:icon><Lucideicons.settings /></:icon>
          <media-quality-radio-group auto-label={dgettext("player", "Auto")} hide-bitrate>
            <template><.player_radio /></template>
          </media-quality-radio-group>
        </.player_menu>

        <.player_menu label={dgettext("player", "Audio")}>
          <:icon><Lucideicons.languages /></:icon>
          <media-audio-radio-group>
            <template><.player_radio /></template>
          </media-audio-radio-group>
        </.player_menu>

        <.player_menu label={dgettext("player", "Subtitles")}>
          <:icon><Lucideicons.captions/></:icon>
          <media-captions-radio-group off-label={dgettext("player", "Off")}>
            <template><.player_radio /></template>
          </media-captions-radio-group>
        </.player_menu>

        <media-mute-button
          class={media_menu_button_style()}
          aria-label={dgettext("player", "Mute")}
        >
          <Lucideicons.volume_2 class="group-data-muted/mute:hidden" />
          <Lucideicons.volume_x class="hidden group-data-muted/mute:block" />
        </media-mute-button>

        <media-fullscreen-button
          target="media"
          class={media_menu_button_style()}
          aria-label={dgettext("player", "Fullscreen")}
        >
          <Lucideicons.maximize class="group-data-active/fullscreen:hidden" />
          <Lucideicons.minimize class="hidden group-data-active/fullscreen:block" />
        </media-fullscreen-button>
      </div>
    </header>
    """
  end

  def controls_center_row(assigns) do
    ~H"""
    <div class="pointer-events-none flex items-center justify-center">
      <div class="pointer-events-auto flex items-center justify-center gap-related opacity-90 transition-opacity group-data-buffering/player:opacity-0">
        <media-seek-button
          seconds="-10"
          class={[media_menu_button_style(), "relative size-20! sm:size-24!"]}
          aria-label={dgettext("player", "Seek backward 10 seconds")}
        >
          <Lucideicons.rotate_ccw class="size-12! sm:size-16!" />
          <span class="absolute mt-1 text-xs font-bold">10</span>
        </media-seek-button>

        <media-play-button
          class={[media_menu_button_style(), "group/play relative size-24! sm:size-28!"]}
          aria-label={dgettext("player", "Play or pause")}
        >
          <Lucideicons.play class="hidden group-data-paused/play:block size-20! sm:size-24!" />
          <Lucideicons.pause class="group-data-paused/play:hidden size-20! sm:size-24!" />
        </media-play-button>

        <media-seek-button
          seconds="10"
          class={[media_menu_button_style(), "relative size-20! sm:size-24!"]}
          aria-label={dgettext("player", "Seek forward 10 seconds")}
        >
          <Lucideicons.rotate_cw class="size-12! sm:size-16!" />
          <span class="absolute mt-1 text-xs font-bold">10</span>
        </media-seek-button>
      </div>
    </div>
    """
  end

  attr :session, Session, required: true

  @doc """
  The lower bar of the control panel of the footer, that contains the seek bar with the thumbnails
  and the duration timer.
  """
  def controls_footer(assigns) do
    ~H"""
    <footer
      class="pointer-events-auto flex flex-col gap-related px-4 pt-4 sm:px-8"
      style="padding-bottom: max(1rem, env(safe-area-inset-bottom));"
    >
      <.seek_bar thumbnails={~p"/player/thumbnails/#{@session.id}/thumbnails.vtt"} />

      <div class="flex items-center justify-center gap-tight text-sm font-medium text-white/90 tabular-nums">
        <media-time type="current">0:00</media-time>
        <span class="text-white/60">/</span>
        <media-time type="duration">
          {format_duration(@session.active_playback.media.video.duration_seconds)}
        </media-time>
      </div>
    </footer>
    """
  end

  @doc """
  Centered spinner shown whenever the player has no frame to display — the
  initial session load and mid-playback buffering both render it.
  """
  attr :class, :string, default: nil, doc: "Positioning and visibility of the overlay."

  def player_loader(assigns) do
    ~H"""
    <div class={["pointer-events-none grid place-items-center", @class]} aria-hidden="true">
      <div class="grid size-24 place-items-center rounded-full bg-black/55 backdrop-blur-sm">
        <Lucideicons.loader_circle class="size-14 animate-spin text-white/90" />
      </div>
    </div>
    """
  end

  @doc """
  An full page overlay displayed when there is an error loading media in the player.
  Contains a CTA that redirects to the homepage
  """
  def player_load_error_overlay(assigns) do
    ~H"""
    <div
      id="watch-club-player-error"
      class="absolute inset-0 z-50 grid place-items-center bg-scrim px-page text-center"
      role="alert"
      aria-live="assertive"
    >
      <.empty>
        <:icon><Lucideicons.triangle_alert /></:icon>
        <:title>{dgettext("player", "Error loading video")}</:title>
        <:description>
          {dgettext("player", "We couldn't find the media you were looking for.")}
        </:description>
        <.button id="player-error-back-button" navigate={~p"/"}>
          {dgettext("player", "Back home")}
        </.button>
      </.empty>
    </div>
    """
  end

  defp media_menu_button_style,
    do:
      "inline-flex size-10 sm:size-12 [&_svg]:size-6 sm:[&_svg]:size-7 items-center justify-center rounded-md text-white outline-none hover:bg-white/20 aria-disabled:pointer-events-none aria-disabled:opacity-40 data-focus:ring-2 data-focus:ring-white/70"

  defp format_duration(duration) do
    total = duration |> trunc() |> max(0)
    hours = div(total, 3600)
    minutes = total |> rem(3600) |> div(60)
    seconds = rem(total, 60)

    if hours > 0 do
      :io_lib.format(~c"~b:~2..0b:~2..0b", [hours, minutes, seconds])
    else
      :io_lib.format(~c"~b:~2..0b", [minutes, seconds])
    end
    |> to_string()
  end

  defp header_title(%Video{movie: %Movie{} = movie}), do: movie.best_localization.title

  defp header_title(%Video{tv_show_episode: %TvShowEpisode{} = episode}),
    do: "#{episode.tv_show.best_localization.title} - #{episode.formatted_episode_number}"
end
