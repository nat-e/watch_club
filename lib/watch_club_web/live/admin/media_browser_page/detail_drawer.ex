defmodule WatchClubWeb.Admin.MediaBrowserPage.DetailDrawer do
  @moduledoc """
  Right-pinned detail drawer for the Admin Media browser.

  Receives a fully-preloaded Media (via `Media.get_media/2` with the heavy
  drawer load tree). Composes hero + Content / Video / Audio / Subtitles /
  File sections as private function components in this same file.
  """
  use WatchClubWeb, :html

  import WatchClubWeb.Components.UI.Avatar
  import WatchClubWeb.Components.UI.Badge
  import WatchClubWeb.Components.UI.Button
  import WatchClubWeb.Components.UI.Layout
  import WatchClubWeb.Components.Media.MediaTypeIcon
  import WatchClubWeb.Components.Medias.MatchedContentSection
  import WatchClubWeb.Components.Medias.UnmatchedContentSection
  import WatchClubWeb.Components.Medias.VideoResolutionBadge
  import WatchClubWeb.Admin.MediaBrowserPage.Filename

  alias WatchClub.Contents.{Movie, TvShowEpisode}
  alias WatchClub.Media.{Audiobook, Ebook, Media, MediaType, Video}
  alias WatchClubWeb.Admin.MediaBrowserPage.RowView
  alias WatchClubWeb.Helpers.Time

  attr :media, Media, required: true
  attr :locale, :atom, required: true

  def render(assigns) do
    view = RowView.from_media(assigns.media)
    has_video? = assigns.media.type in [:movie, :tv_show_episode]
    assigns = assigns |> assign(:view, view) |> assign(:has_video?, has_video?)

    ~H"""
    <aside class="grid h-full content-start overflow-hidden border border-border bg-surface shadow-card rounded-l-card lg:rounded-card">
      <.hero view={@view} media={@media} />

      <div class="grid gap-cluster p-cluster">
        <.content_section view={@view} media={@media} />
        <.library_section view={@view} />
        <.video_section :if={@has_video?} media={@media} view={@view} />
        <.audio_section :if={@has_video?} media={@media} />
        <.subtitle_section :if={@has_video?} media={@media} />
        <.file_section media={@media} locale={@locale} />
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
        <.eyebrow class="grow">
          {MediaType.translated_label(@view.media_type)}
        </.eyebrow>
        <.button
          id="drawer-close"
          size="icon-sm"
          variant="ghost"
          phx-click="close_drawer"
          aria-label="Close drawer"
        >
          <Lucideicons.x />
        </.button>
      </div>

      <.file_name
        file_name={@view.file_name}
        wrap
        class="font-mono text-base text-text-muted"
      />

      <.cluster space="related">
        <.button id="drawer-play" variant="accent" size="md" emphasis>
          <:icon><.dynamic_icon name={play_icon(@view.media_type)} class="size-icon-sm" /></:icon>
          {play_label(@view.media_type)}
        </.button>
        <.button
          id="drawer-delete"
          variant="danger"
          size="md"
          phx-click="delete_media"
          data-confirm="Delete this Media? This cannot be undone."
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

  defp content_section(%{media: %Media{video: %Video{movie: %Movie{}}}} = assigns) do
    ~H"""
    <.section_block label="Content">
      <.matched_content_section content={@media.video.movie} />
    </.section_block>
    """
  end

  defp content_section(
         %{media: %Media{video: %Video{tv_show_episode: %TvShowEpisode{}}}} = assigns
       ) do
    ~H"""
    <.section_block label="Content">
      <.matched_content_section content={@media.video.tv_show_episode} />
    </.section_block>
    """
  end

  defp content_section(%{media: %Media{ebook: %Ebook{}}} = assigns) do
    ~H"""
    <.section_block label="Content">
      <.matched_content_section content={@media.ebook.book} />
    </.section_block>
    """
  end

  defp content_section(%{media: %Media{audiobook: %Audiobook{}}} = assigns) do
    ~H"""
    <.section_block label="Content">
      <.matched_content_section content={@media.audiobook.book} />
    </.section_block>
    """
  end

  defp content_section(assigns) do
    ~H"""
    <.section_block label="Content">
      <.unmatched_content_section file_name={@view.file_name} />
    </.section_block>
    """
  end

  attr :view, :map, required: true

  defp library_section(%{view: %{libraries: []}} = assigns) do
    ~H"""
    <.section_block label="Libraries">
      <p class="text-base text-text-subtle">This content is not in any Library.</p>
    </.section_block>
    """
  end

  defp library_section(assigns) do
    ~H"""
    <.section_block label="Libraries">
      <ul class="grid gap-related">
        <li
          :for={library <- @view.libraries}
          class="flex items-center gap-related text-base text-text"
        >
          <.avatar id={library.club.id} name={library.club.name} size="sm" />
          <span class="min-w-0 truncate">{library.name}</span>
        </li>
      </ul>
    </.section_block>
    """
  end

  attr :media, Media, required: true
  attr :view, :map, required: true

  defp video_section(assigns) do
    ~H"""
    <.section_block label="Video">
      <.dl>
        <.dl_badge_row label="Resolution">
          <.video_resolution_badge video={@media.video} />
        </.dl_badge_row>
        <.dl_badge_row :if={video_codec(@media)} label="Codec">
          <.badge variant="muted">{video_codec(@media)}</.badge>
        </.dl_badge_row>
        <.dl_badge_row :if={@media.video && @media.video.container} label="Container">
          <.badge variant="muted">{@media.video.container}</.badge>
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
      <ul class="grid gap-related">
        <li
          :for={track <- @tracks}
          class="flex items-center justify-between gap-related text-base"
        >
          <div class="flex items-center gap-related min-w-0">
            <span class="text-lg leading-none">
              {WatchClub.Languages.to_flag(track.language)}
            </span>
            <span class="truncate text-text">
              {WatchClub.Languages.to_name(track.language) || "—"}
            </span>
          </div>
          <div class="flex items-center gap-tight shrink-0">
            <.badge :if={track.codec} variant="muted">{track.codec}</.badge>
            <.badge :if={track.channels} variant="muted">
              {channels_label(track.channels)}
            </.badge>
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
      <ul class="grid gap-related">
        <li
          :for={track <- @tracks}
          class="flex items-center justify-between gap-related text-base"
        >
          <div class="flex items-center gap-related min-w-0">
            <span class="text-lg leading-none">
              {WatchClub.Languages.to_flag(track.language)}
            </span>
            <span class="truncate text-text">
              {WatchClub.Languages.to_name(track.language) || "—"}
            </span>
          </div>
          <.badge :if={Map.get(track, :default?)} variant="muted">Default</.badge>
          <.badge :if={Map.get(track, :forced?)} variant="muted">Forced</.badge>
        </li>
      </ul>
    </.section_block>
    """
  end

  defp subtitle_section(assigns), do: ~H""

  attr :media, Media, required: true
  attr :locale, :atom, required: true

  defp file_section(assigns) do
    ~H"""
    <.section_block label="File">
      <.dl>
        <.dl_row label="Path" value={@media.path} mono />
        <.dl_row
          :if={@media.updated_at}
          label="Last updated"
          value={Time.relative_from_now(@media.updated_at, @locale)}
        />
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
        <.eyebrow as="h3">{@label}</.eyebrow>
        {render_slot(@inner_block)}
      </.stack>
    </section>
    """
  end

  attr :as, :string, values: ~w(span h3), default: "span"
  attr :class, :any, default: nil
  slot :inner_block, required: true

  defp eyebrow(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={@as}
      class={[
        "text-xs font-semibold uppercase tracking-[0.18em] text-text-subtle",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </.dynamic_tag>
    """
  end

  slot :inner_block, required: true

  defp dl(assigns) do
    ~H"""
    <dl class="grid grid-cols-[7rem_minmax(0,1fr)] items-center gap-x-related gap-y-related text-base">
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
      @mono && "font-mono text-sm text-text-muted"
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

  defp video_codec(%Media{video: %Video{default_video_track: %{codec: codec}}})
       when is_binary(codec),
       do: codec

  defp video_codec(_), do: nil

  defp frame_rate(%Media{video: %Video{default_video_track: %{frame_rate: fr}}})
       when not is_nil(fr),
       do: "#{round(fr)} fps"

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
end
