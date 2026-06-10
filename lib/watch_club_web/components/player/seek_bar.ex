defmodule WatchClubWeb.Components.Player.SeekBar do
  @moduledoc """
  The player's seek bar: a custom-skinned Vidstack `media-time-slider` with a
  scrubbing preview.

  Hovering or dragging the bar shows a trickplay thumbnail (cropped from the
  sprite sheets the `thumbnails` WebVTT manifest references) above a timestamp.
  Vidstack handles the
  pointer tracking, cue lookup, and tile cropping; when no trickplay exists yet
  the thumbnail 404s and Vidstack hides it (`data-hidden`), leaving just the
  timestamp.
  """
  use WatchClubWeb, :component

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
          class="block overflow-hidden rounded-control border border-white/15 bg-black shadow-overlay data-hidden:hidden"
          style="width: var(--thumbnail-width); height: var(--thumbnail-height); contain: strict; min-width: 120px; min-height: 80px; max-width: 220px; max-height: 160px;"
        >
        </media-slider-thumbnail>
        <media-slider-value class="rounded-control bg-black/80 px-related py-tight text-xs font-medium text-white tabular-nums">
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
end
