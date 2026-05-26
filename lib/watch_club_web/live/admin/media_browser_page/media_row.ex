defmodule WatchClubWeb.Admin.MediaBrowserPage.MediaRow do
  @moduledoc """
  One row in the Admin Media browser. Renders a `Media` struct through
  `RowView` to keep presentational logic out of HEEX.
  """
  use WatchClubWeb, :html

  import WatchClubWeb.Components.UI.Badge
  import WatchClubWeb.Components.Media.MediaTypeIcon
  import WatchClubWeb.Components.Medias.LanguageFlags
  import WatchClubWeb.Components.Medias.LibraryLists
  import WatchClubWeb.Components.Medias.VideoResolutionBadge
  import WatchClubWeb.Admin.MediaBrowserPage.Filename

  alias WatchClubWeb.Admin.MediaBrowserPage.RowView
  alias WatchClubWeb.Helpers.Time

  attr :id, :string, required: true
  attr :row, :map, required: true, doc: "raw Media struct from the stream"
  attr :selected, :boolean, default: false
  attr :locale, :atom, required: true

  def row(assigns) do
    view = RowView.from_media(assigns.row)
    assigns = assign(assigns, :view, view)

    ~H"""
    <tr
      id={@id}
      phx-click="open_drawer"
      phx-value-id={@view.id}
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
            <.media_type_icon media_type={@view.media_type} class="size-icon-sm" />
          </span>
          <.file_name file_name={@view.file_name} class="text-sm font-medium text-text" />
        </div>
      </td>
      <td class="px-related py-2.5 align-middle max-w-[20rem]">
        <div
          class="flex items-center gap-tight min-w-0"
          title={matched_content_inline(@view)}
        >
          <span class="truncate text-sm text-text-muted">
            {@view.content_title || "—"}
          </span>
          <.badge :if={@view.content_sub} variant="secondary" size="sm" class="shrink-0">
            {@view.content_sub}
          </.badge>
        </div>
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
          {Time.relative_from_now(@view.imported_at, @locale)}
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
    view = RowView.from_media(assigns.row)
    assigns = assign(assigns, :view, view)

    ~H"""
    <li
      id={@id}
      phx-click="open_drawer"
      phx-value-id={@view.id}
      class={[
        "flex flex-col gap-related rounded-card border border-border bg-surface p-4 shadow-card",
        "transition-colors cursor-pointer hover:bg-surface-hover",
        @selected && "ring-2 ring-focus-ring border-border-focus"
      ]}
    >
      <div class="flex items-center gap-tight min-w-0">
        <.media_type_icon
          media_type={@view.media_type}
          class="size-icon shrink-0 text-text-subtle"
        />
        <.file_name file_name={@view.file_name} class="text-sm font-medium text-text" />
      </div>

      <.identity_line view={@view} />

      <.media_libraries_chips media={@row} />
    </li>
    """
  end

  attr :view, :map, required: true

  defp identity_line(%{view: %{content_title: nil}} = assigns) do
    ~H"""
    <p class="text-sm italic text-text-subtle">Unmatched</p>
    """
  end

  defp identity_line(assigns) do
    ~H"""
    <p class="truncate text-sm text-text-muted">{identity_text(@view)}</p>
    """
  end

  defp identity_text(%{content_title: title, content_sub: sub}) when is_binary(sub),
    do: "#{title} · #{sub}"

  defp identity_text(%{content_title: title, release_year: year}) when is_integer(year),
    do: "#{title} · #{year}"

  defp identity_text(%{content_title: title}), do: title

  defp matched_content_inline(%{content_title: nil}), do: "—"

  defp matched_content_inline(%{content_title: title, content_sub: nil}), do: title

  defp matched_content_inline(%{content_title: title, content_sub: sub}),
    do: "#{title} · #{sub}"
end
