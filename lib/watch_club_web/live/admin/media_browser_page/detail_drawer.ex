defmodule WatchClubWeb.Admin.MediaBrowserPage.DetailDrawer do
  @moduledoc """
  Right-pinned detail drawer for the Admin Media browser.

  Receives a fully-preloaded Media (via `Media.get_media/2` with the heavy
  drawer load tree). Composes hero + Content / Video / Audio / Subtitles /
  File sections as private function components in this same file.
  """
  use WatchClubWeb, :html

  import WatchClubWeb.Components.UI.Badge
  import WatchClubWeb.Components.UI.Button
  import WatchClubWeb.Components.UI.Layout
  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Components.Media.MediaTypeIcon
  import WatchClubWeb.Admin.MediaBrowserPage.Filename

  alias WatchClub.Media.{Media, MediaType, Video}
  alias WatchClubWeb.Admin.MediaBrowserPage.RowView

  attr :media, Media, required: true

  def render(assigns) do
    view = RowView.from_media(assigns.media)
    has_video? = assigns.media.type in [:movie, :tv_show_episode]
    assigns = assigns |> assign(:view, view) |> assign(:has_video?, has_video?)

    ~H"""
    <aside class="grid h-full content-start overflow-hidden border border-border bg-surface shadow-card rounded-l-card lg:rounded-card">
      <.hero view={@view} media={@media} />

      <div class="grid gap-cluster p-cluster">
        <.content_section view={@view} media={@media} />
        <.video_section :if={@has_video?} media={@media} view={@view} />
        <.audio_section :if={@has_video?} media={@media} />
        <.subtitle_section :if={@has_video?} media={@media} />
        <.file_section media={@media} />
      </div>
    </aside>
    """
  end

  attr :view, :map, required: true
  attr :media, Media, required: true

  defp hero(assigns) do
    ~H"""
    <header class="grid gap-group border-b border-border-subtle p-cluster">
      <div class="flex items-center gap-related min-w-0">
        <span class="grid size-9 shrink-0 place-items-center rounded-control border border-border-subtle bg-surface-inset text-text-muted">
          <.media_type_icon media_type={@view.media_type} class="size-icon" />
        </span>
        <.stack space="tight" class="min-w-0 grow">
          <span class="text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-text-subtle">
            {MediaType.translated_label(@view.media_type)} file
          </span>
          <.file_name file_name={@view.file_name} class="font-mono text-sm text-text" />
        </.stack>
        <button
          type="button"
          phx-click="close_drawer"
          class="shrink-0 rounded-control p-1 text-text-subtle hover:bg-surface-raised hover:text-text"
          aria-label="Close drawer"
        >
          <Lucideicons.x class="size-icon-sm" />
        </button>
      </div>
      <.cluster space="related">
        <.button id="drawer-play" variant="accent" size="md" emphasis>
          <:icon><.dynamic_icon name={play_icon(@view.media_type)} class="size-icon-sm" /></:icon>
          {play_label(@view.media_type)}
        </.button>
        <.button
          id="drawer-delete"
          variant="ghost"
          size="md"
          phx-click="delete_media"
          data-confirm="Delete this Media? This cannot be undone."
          class="text-danger hover:bg-danger-bg hover:text-danger"
        >
          <:icon><Lucideicons.trash_2 /></:icon>
          Delete
        </.button>
      </.cluster>
    </header>
    """
  end

  attr :view, :map, required: true
  attr :media, Media, required: true

  defp content_section(assigns) do
    ~H"""
    <.stack space="related">
      <div class="grid grid-cols-[6rem_minmax(0,1fr)] items-start gap-cluster">
        <.tmdb_poster
          path={nil}
          size="w154"
          alt={@view.content_title || @view.file_name}
          class="rounded-control border border-border-subtle"
        />

        <.stack space="tight" class="min-w-0 self-center">
          <h2 class="text-xl font-heading font-semibold leading-tight tracking-tight text-text">
            {@view.content_title || "Unmatched"}
          </h2>
          <ul class="flex flex-wrap items-center gap-related text-sm text-text-muted">
            <li :for={{item, index} <- Enum.with_index(content_meta(@view))} class="flex items-center gap-related">
              <span :if={index > 0} aria-hidden="true">·</span>
              <span>{item}</span>
            </li>
          </ul>
        </.stack>
      </div>

      <.cluster :if={@view.clubs != []} space="tight">
        <.badge :for={club <- @view.clubs} variant="secondary" size="sm">
          <:icon><Lucideicons.library /></:icon>
          <span class="max-w-[14rem] truncate">{club.name}</span>
        </.badge>
      </.cluster>
      <p :if={@view.clubs == []} class="text-sm text-text-subtle">
        Not reachable from any Club.
      </p>
    </.stack>
    """
  end

  attr :media, Media, required: true
  attr :view, :map, required: true

  defp video_section(assigns) do
    ~H"""
    <.section_block label="Video">
      <.dl>
        <.dl_badge_row label="Resolution">
          <.badge :if={@view.resolution} variant="muted" size="sm">
            {RowView.resolution_label(@view.resolution)}
          </.badge>
          <span :if={!@view.resolution} class="text-xs text-text-subtle">—</span>
        </.dl_badge_row>
        <.dl_badge_row :if={video_codec(@media)} label="Codec">
          <.badge variant="muted" size="sm">{video_codec(@media)}</.badge>
        </.dl_badge_row>
        <.dl_badge_row :if={@media.video && @media.video.container} label="Container">
          <.badge variant="muted" size="sm">{@media.video.container}</.badge>
        </.dl_badge_row>
        <.dl_row :if={frame_rate(@media)} label="Frame rate" value={frame_rate(@media)} />
      </.dl>
    </.section_block>
    """
  end

  attr :media, Media, required: true

  defp audio_section(%{media: %Media{video: %Video{audio_tracks: tracks}}} = assigns)
       when is_list(tracks) and tracks != [] do
    assigns = assign(assigns, :tracks, tracks)

    ~H"""
    <.section_block label={"Audio (#{length(@tracks)})"}>
      <ul class="grid gap-tight">
        <li
          :for={track <- @tracks}
          class="flex items-center justify-between gap-related text-sm"
        >
          <div class="flex items-center gap-related min-w-0">
            <span class="text-base leading-none">
              {RowView.language_flag(track.language || "und")}
            </span>
            <span class="truncate text-text">{track.language || "—"}</span>
          </div>
          <div class="flex items-center gap-tight shrink-0">
            <.badge :if={track.codec} variant="muted" size="sm">{track.codec}</.badge>
            <.badge :if={track.channels} variant="muted" size="sm">{channels_label(track.channels)}</.badge>
          </div>
        </li>
      </ul>
    </.section_block>
    """
  end

  defp audio_section(assigns), do: ~H""

  attr :media, Media, required: true

  defp subtitle_section(%{media: %Media{video: %Video{text_tracks: tracks}}} = assigns)
       when is_list(tracks) and tracks != [] do
    assigns = assign(assigns, :tracks, tracks)

    ~H"""
    <.section_block label={"Subtitles (#{length(@tracks)})"}>
      <ul class="grid gap-tight">
        <li
          :for={track <- @tracks}
          class="flex items-center justify-between gap-related text-sm"
        >
          <div class="flex items-center gap-related min-w-0">
            <span class="text-base leading-none">
              {RowView.language_flag(track.language || "und")}
            </span>
            <span class="truncate text-text">{track.language || "—"}</span>
          </div>
          <.badge :if={Map.get(track, :default?)} variant="muted" size="sm">Default</.badge>
          <.badge :if={Map.get(track, :forced?)} variant="muted" size="sm">Forced</.badge>
        </li>
      </ul>
    </.section_block>
    """
  end

  defp subtitle_section(assigns), do: ~H""

  attr :media, Media, required: true

  defp file_section(assigns) do
    ~H"""
    <.section_block label="File">
      <.dl>
        <.dl_row label="Path" value={@media.path} mono />
        <.dl_row label="Imported" value={format_dt(@media.inserted_at)} />
        <.dl_row :if={@media.updated_at} label="Updated" value={format_dt(@media.updated_at)} />
      </.dl>
    </.section_block>
    """
  end

  # --------------------------------------------------------------------------
  # Small primitives
  # --------------------------------------------------------------------------

  attr :label, :string, required: true
  slot :inner_block, required: true

  defp section_block(assigns) do
    ~H"""
    <section>
      <.stack space="related">
        <h3 class="text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-text-subtle">
          {@label}
        </h3>
        {render_slot(@inner_block)}
      </.stack>
    </section>
    """
  end

  slot :inner_block, required: true

  defp dl(assigns) do
    ~H"""
    <dl class="grid grid-cols-[7rem_minmax(0,1fr)] items-center gap-x-related gap-y-related text-sm">
      {render_slot(@inner_block)}
    </dl>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :mono, :boolean, default: false

  defp dl_row(assigns) do
    ~H"""
    <dt class="text-text-subtle">{@label}</dt>
    <dd class={[
      "min-w-0 break-words text-text",
      @mono && "font-mono text-xs text-text-muted"
    ]}>
      {@value}
    </dd>
    """
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  defp dl_badge_row(assigns) do
    ~H"""
    <dt class="text-text-subtle">{@label}</dt>
    <dd class="min-w-0">
      {render_slot(@inner_block)}
    </dd>
    """
  end

  attr :name, :atom, required: true
  attr :class, :string, default: "size-icon"

  defp dynamic_icon(assigns) do
    ~H"""
    {apply(Lucideicons, @name, [%{class: @class, __changed__: %{}}])}
    """
  end

  # --------------------------------------------------------------------------
  # Helpers
  # --------------------------------------------------------------------------

  defp play_icon(:ebook), do: :book_open
  defp play_icon(_), do: :play

  defp play_label(:ebook), do: "Read"
  defp play_label(_), do: "Play"

  defp content_meta(%{media_type: :tv_show_episode, content_sub: sub}) when is_binary(sub),
    do: [MediaType.translated_label(:tv_show_episode), sub]

  defp content_meta(%{media_type: type}) when type in [:movie, :tv_show_episode, :ebook, :audiobook],
    do: [MediaType.translated_label(type)]

  defp content_meta(_), do: []

  defp video_codec(%Media{video: %Video{video_tracks: [%{codec: codec} | _]}}) when is_binary(codec),
    do: codec

  defp video_codec(_), do: nil

  defp frame_rate(%Media{video: %Video{video_tracks: [%{frame_rate: fr} | _]}}) when not is_nil(fr),
    do: "#{fr} fps"

  defp frame_rate(_), do: nil

  defp channels_label(n) when is_integer(n) do
    case n do
      2 -> "2.0"
      6 -> "5.1"
      8 -> "7.1"
      other -> "#{other}.0"
    end
  end

  defp channels_label(s) when is_binary(s), do: s
  defp channels_label(_), do: nil

  defp format_dt(nil), do: "—"

  defp format_dt(%DateTime{} = dt),
    do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  defp format_dt(%NaiveDateTime{} = ndt),
    do: Calendar.strftime(ndt, "%Y-%m-%d %H:%M")

  defp format_dt(_), do: "—"
end
