defmodule WatchClubWeb.Admin.MediaBrowserPage.MediaRow do
  @moduledoc """
  One row in the Admin Media browser. Renders a `Media` struct as either a
  table row (`row/1`) or a mobile card (`card/1`).
  """
  use WatchClubWeb, :html

  import WatchClubWeb.Components.Media.MediaTypeIcon
  import WatchClubWeb.Components.Medias.LanguageFlags
  import WatchClubWeb.Components.Medias.LibraryLists
  import WatchClubWeb.Components.Medias.MatchedContentIdentity
  import WatchClubWeb.Components.Medias.MatchedContentInline
  import WatchClubWeb.Components.Medias.VideoResolutionBadge
  import WatchClubWeb.Admin.MediaBrowserPage.Filename

  alias WatchClub.Contents.{Movie, TvShowEpisode}
  alias WatchClub.Media.{Audiobook, Ebook, Media, Video}
  alias WatchClubWeb.Helpers.Time

  attr :id, :string, required: true
  attr :row, :map, required: true, doc: "raw Media struct from the stream"
  attr :selected, :boolean, default: false
  attr :locale, :atom, required: true

  def row(assigns) do
    ~H"""
    <tr
      id={@id}
      phx-click="open_drawer"
      phx-value-id={@row.id}
      class={[
        "border-b border-border-subtle transition-colors cursor-pointer",
        "hover:bg-surface-hover",
        @selected && "bg-surface-selected"
      ]}
    >
      <!--
        max-w-0 on a table cell is the canonical truncation idiom: the cell
        still claims its share of the table width, but the inner truncate
        sees a 0-width constraint and clips cleanly at the column boundary.
      -->
      <td class="px-related py-2.5 align-middle w-full max-w-0">
        <div class="flex items-center gap-related min-w-0">
          <span class="grid size-7 shrink-0 place-items-center rounded-control border border-border-subtle bg-surface-inset text-text-muted">
            <.media_type_icon media_type={@row.type} class="size-icon-sm" />
          </span>
          <.file_name
            file_name={Path.basename(@row.path || "")}
            class="text-sm font-medium text-text"
          />
        </div>
      </td>
      <td class="px-related py-2.5 align-middle max-w-[20rem]">
        <.content_cell row={@row} />
      </td>
      <td class="px-related py-2.5 align-middle w-px whitespace-nowrap [[data-browser][data-drawer=open]_&]:hidden">
        <.media_clubs_avatars media={@row} />
      </td>
      <td class="px-related py-2.5 align-middle w-px whitespace-nowrap [[data-browser][data-drawer=open]_&]:hidden">
        <.audio_languages_flags video={@row.video} />
      </td>
      <td class="px-related py-2.5 align-middle w-px whitespace-nowrap [[data-browser][data-drawer=open]_&]:hidden">
        <.subtitle_languages_flags video={@row.video} />
      </td>
      <td class="px-related py-2.5 align-middle w-px whitespace-nowrap [[data-browser][data-drawer=open]_&]:hidden">
        <.video_resolution_badge video={@row.video} size="sm" class="text-xs" />
      </td>
      <td class="px-related py-2.5 align-middle w-px whitespace-nowrap">
        <span class="text-xs text-text-subtle">
          {Time.relative_from_now(@row.inserted_at, @locale)}
        </span>
      </td>
    </tr>
    """
  end

  attr :id, :string, required: true
  attr :row, :map, required: true, doc: "raw Media struct from the stream"
  attr :selected, :boolean, default: false
  attr :locale, :atom, required: true

  def card(assigns) do
    ~H"""
    <li
      id={@id}
      phx-click="open_drawer"
      phx-value-id={@row.id}
      class={[
        "flex flex-col gap-related rounded-card border border-border bg-surface p-4 shadow-card",
        "transition-colors cursor-pointer hover:bg-surface-hover",
        @selected && "ring-2 ring-focus-ring border-border-focus"
      ]}
    >
      <div class="flex items-center gap-tight min-w-0">
        <.media_type_icon
          media_type={@row.type}
          class="size-icon shrink-0 text-text-subtle"
        />
        <.file_name file_name={Path.basename(@row.path || "")} class="text-sm font-medium text-text" />
      </div>

      <.identity_line row={@row} />

      <.media_libraries_chips media={@row} />
    </li>
    """
  end

  # --------------------------------------------------------------------------
  # Polymorphic dispatch: extract the matched content struct or render the
  # unmatched fallback.
  # --------------------------------------------------------------------------

  attr :row, Media, required: true

  defp content_cell(%{row: %Media{video: %Video{movie: %Movie{} = movie}}} = assigns) do
    assigns = assign(assigns, :content, movie)

    ~H"""
    <.matched_content_inline content={@content} />
    """
  end

  defp content_cell(
         %{row: %Media{video: %Video{tv_show_episode: %TvShowEpisode{} = episode}}} = assigns
       ) do
    assigns = assign(assigns, :content, episode)

    ~H"""
    <.matched_content_inline content={@content} />
    """
  end

  defp content_cell(%{row: %Media{ebook: %Ebook{book: book}}} = assigns) do
    assigns = assign(assigns, :content, book)

    ~H"""
    <.matched_content_inline content={@content} />
    """
  end

  defp content_cell(%{row: %Media{audiobook: %Audiobook{book: book}}} = assigns) do
    assigns = assign(assigns, :content, book)

    ~H"""
    <.matched_content_inline content={@content} />
    """
  end

  defp content_cell(assigns) do
    ~H"""
    <span class="text-sm text-text-subtle">—</span>
    """
  end

  attr :row, Media, required: true

  defp identity_line(%{row: %Media{video: %Video{movie: %Movie{} = movie}}} = assigns) do
    assigns = assign(assigns, :content, movie)

    ~H"""
    <.matched_content_identity content={@content} />
    """
  end

  defp identity_line(
         %{row: %Media{video: %Video{tv_show_episode: %TvShowEpisode{} = episode}}} = assigns
       ) do
    assigns = assign(assigns, :content, episode)

    ~H"""
    <.matched_content_identity content={@content} />
    """
  end

  defp identity_line(%{row: %Media{ebook: %Ebook{book: book}}} = assigns) do
    assigns = assign(assigns, :content, book)

    ~H"""
    <.matched_content_identity content={@content} />
    """
  end

  defp identity_line(%{row: %Media{audiobook: %Audiobook{book: book}}} = assigns) do
    assigns = assign(assigns, :content, book)

    ~H"""
    <.matched_content_identity content={@content} />
    """
  end

  defp identity_line(assigns) do
    ~H"""
    <p class="text-sm italic text-text-subtle">Unmatched</p>
    """
  end
end
