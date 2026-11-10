defmodule WatchClubWeb.Admin.MediaBrowserPage.MediaDetails do
  @moduledoc """
  The selected Media beside the Media Browser's list: what it is, Play, and a menu to Match or
  Rematch a Video, regenerate its thumbnails and markers, and Remove media, then its video, audio
  and subtitle tracks and its file.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Admin.MediaBrowserPage.MediaPoster
  import WatchClubWeb.Components.Media.MediaTypeBadge
  import WatchClubWeb.Components.Medias.VideoResolutionBadge

  attr :media, Media,
    required: true,
    doc: "with its `content`'s `title` and `poster_path`, and its `video`'s tracks and episode"

  attr :locale, :atom, required: true

  def media_details(assigns) do
    assigns =
      assign(assigns,
        video?: assigns.media.type in [:movie, :tv_show_episode, :sports_event],
        episode: assigns.media.video && assigns.media.video.tv_show_episode
      )

    ~H"""
    <div class="flex flex-col gap-cluster p-cluster">
      <div class="flex items-start justify-between gap-related">
        <h2 class="min-w-0 font-heading text-lg leading-tight font-semibold wrap-break-word">
          {if @media.content,
            do: content_title(@media.content),
            else: Path.basename(@media.path)}
        </h2>
        <%!-- Narrow screens go back to the list with the app bar's arrow --%>
        <.button
          id="close-details"
          variant="ghost"
          size="icon-sm"
          phx-click="close_details"
          aria-label={dgettext("admin_media", "Close details")}
          class="-mt-tight -mr-related @max-split-view/main:hidden"
        >
          <Lucideicons.x />
        </.button>
      </div>

      <div class="flex flex-col gap-group">
        <div class="flex items-start gap-group">
          <.media_poster media={@media} size="lg" />
          <div class="flex min-w-0 flex-col items-start gap-related">
            <p
              :if={@media.content}
              class="flex flex-wrap items-center gap-x-related text-sm text-text-muted"
            >
              <.badge :if={@episode} variant="secondary" size="sm" class="tabular-nums">
                {@episode.formatted_episode_number}
              </.badge>
              <span>{Time.maybe_year(@media.content.release_date)}</span>
              <span>
                {WatchClub.Languages.country_flag(@media.content.origin_country)} {@media.content.origin_country}
              </span>
            </p>
            <p :if={!@media.content} class="text-sm text-text-muted">
              {dgettext("admin_media", "This file isn't matched to a title.")}
            </p>
            <.badge variant="muted" size="sm">
              <:icon><.media_type_icon media_type={@media.type} /></:icon>
              {MediaType.translated_label(@media.type)}
            </.badge>
          </div>
        </div>
        <div class="flex flex-wrap gap-related">
          <.button :if={@video?} id="play-media" navigate={~p"/play/#{@media.id}"}>
            <:icon><Lucideicons.play /></:icon>
            {dgettext("admin_media", "Play")}
          </.button>
          <.dropdown_menu id="media-actions">
            <:trigger>
              <.button
                id="media-actions-button"
                variant="secondary"
                size="icon"
                aria-label={dgettext("admin_media", "More actions")}
              >
                <Lucideicons.ellipsis />
              </.button>
            </:trigger>
            <.dropdown_menu_item :if={@video?} id="match-media" phx-click="open_match_media_modal">
              <Lucideicons.file_search />
              {if @media.content,
                do: dgettext("admin_media", "Rematch"),
                else: dgettext("admin_media", "Match")}
            </.dropdown_menu_item>
            <.dropdown_menu_item
              :if={@video?}
              id="regenerate-thumbnails-and-markers"
              phx-click="regenerate_thumbnails_and_markers"
            >
              <Lucideicons.refresh_cw />
              {dgettext("admin_media", "Regenerate thumbnails and markers")}
            </.dropdown_menu_item>
            <.dropdown_menu_separator :if={@video?} />
            <.dropdown_menu_item
              id="remove-media"
              variant="destructive"
              phx-click="open_remove_media_modal"
            >
              <Lucideicons.trash_2 /> {dgettext("admin_media", "Remove media")}
            </.dropdown_menu_item>
          </.dropdown_menu>
        </div>
      </div>

      <.details_section :if={@video?} label={dgettext("admin_media", "Video")}>
        <.video_details video={@media.video} />
      </.details_section>

      <.details_section
        :if={@video?}
        label={dgettext("admin_media", "Audio (%{count})", count: length(@media.video.audio_tracks))}
      >
        <dl class="grid grid-cols-[auto_minmax(0,1fr)] items-center gap-x-group gap-y-related text-sm">
          <%= for track <- @media.video.audio_tracks do %>
            <dt><.language language={track.language} /></dt>
            <dd class="flex items-center gap-tight">
              <.badge :if={track.codec} variant="muted" size="sm">{track.codec}</.badge>
              <.badge :if={track.channels} variant="muted" size="sm">
                {channels_label(track.channels)}
              </.badge>
            </dd>
          <% end %>
        </dl>
      </.details_section>

      <.details_section
        :if={@video?}
        label={
          dgettext("admin_media", "Subtitles (%{count})", count: length(@media.video.text_tracks))
        }
      >
        <p :if={@media.video.text_tracks == []} class="text-sm text-text-muted">
          {dgettext("admin_media", "None")}
        </p>
        <dl
          :if={@media.video.text_tracks != []}
          class="grid grid-cols-[auto_minmax(0,1fr)] items-center gap-x-group gap-y-related text-sm"
        >
          <%= for track <- @media.video.text_tracks do %>
            <dt><.language language={track.language} /></dt>
            <dd class="flex items-center gap-tight">
              <.badge :if={track.default?} variant="muted" size="sm">
                {dgettext("admin_media", "Default")}
              </.badge>
              <.badge :if={track.forced?} variant="muted" size="sm">
                {dgettext("admin_media", "Forced")}
              </.badge>
            </dd>
          <% end %>
        </dl>
      </.details_section>

      <.details_section label={dgettext("admin_media", "File")}>
        <p class="font-mono text-xs break-all text-text-muted">{@media.path}</p>
        <dl class="grid grid-cols-[auto_minmax(0,1fr)] gap-x-group gap-y-related text-sm">
          <dt class="text-text-muted">{dgettext("admin_media", "Added")}</dt>
          <dd>{Time.relative_or_date!(@media.inserted_at, @locale)}</dd>
        </dl>
      </.details_section>
    </div>
    """
  end

  attr :video, Video, required: true

  defp video_details(assigns) do
    assigns = assign(assigns, :track, assigns.video.default_video_track)

    ~H"""
    <dl class="grid grid-cols-[auto_minmax(0,1fr)] items-center gap-x-group gap-y-related text-sm">
      <dt class="text-text-muted">{dgettext("admin_media", "Resolution")}</dt>
      <dd><.video_resolution_badge video={@video} size="sm" /></dd>
      <dt :if={@track && @track.codec} class="text-text-muted">
        {dgettext("admin_media", "Codec")}
      </dt>
      <dd :if={@track && @track.codec}>
        <.badge variant="muted" size="sm">{@track.codec}</.badge>
      </dd>
      <dt :if={@video.container} class="text-text-muted">{dgettext("admin_media", "Container")}</dt>
      <dd :if={@video.container}>
        <.badge variant="muted" size="sm">{@video.container}</.badge>
      </dd>
      <dt :if={@track && @track.frame_rate} class="text-text-muted">
        {dgettext("admin_media", "Frame rate")}
      </dt>
      <dd :if={@track && @track.frame_rate}>
        {dgettext("admin_media", "%{count} fps", count: round(@track.frame_rate))}
      </dd>
    </dl>
    """
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  defp details_section(assigns) do
    ~H"""
    <section class="flex min-w-0 flex-col gap-related">
      <h3 class="text-xs font-semibold tracking-wider text-text-subtle uppercase">{@label}</h3>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :language, :string, required: true

  defp language(assigns) do
    ~H"""
    <span class="flex min-w-0 items-center gap-related">
      <span class="text-base leading-none">{WatchClub.Languages.to_flag(@language)}</span>
      <span class="truncate text-text">{WatchClub.Languages.to_name(@language) || "—"}</span>
    </span>
    """
  end

  defp channels_label(2), do: "2.0"
  defp channels_label(6), do: "5.1"
  defp channels_label(8), do: "7.1"
  defp channels_label(channels), do: "#{channels}.0"
end
