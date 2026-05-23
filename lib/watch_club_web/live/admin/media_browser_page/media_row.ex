defmodule WatchClubWeb.Admin.MediaBrowserPage.MediaRow do
  @moduledoc """
  One row in the Admin Media browser. Renders a `Media` struct through
  `RowView` to keep presentational logic out of HEEX.
  """
  use WatchClubWeb, :html

  import WatchClubWeb.Components.UI.Avatar
  import WatchClubWeb.Components.UI.Badge
  import WatchClubWeb.Components.Media.MediaTypeIcon
  import WatchClubWeb.Admin.MediaBrowserPage.Filename

  alias WatchClubWeb.Admin.MediaBrowserPage.RowView

  attr :id, :string, required: true
  attr :row, :map, required: true, doc: "raw Media struct from the stream"
  attr :selected, :boolean, default: false

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
        <span class="block truncate text-sm text-text-muted" title={matched_content_inline(@view)}>
          {matched_content_inline(@view)}
        </span>
      </td>
      <td class="px-related py-2.5 align-middle w-px whitespace-nowrap [[data-browser][data-drawer=open]_&]:hidden">
        <.clubs_avatars clubs={@view.clubs} />
      </td>
      <td class="px-related py-2.5 align-middle w-px whitespace-nowrap [[data-browser][data-drawer=open]_&]:hidden">
        <.flag_strip langs={@view.audio_languages} />
      </td>
      <td class="px-related py-2.5 align-middle w-px whitespace-nowrap [[data-browser][data-drawer=open]_&]:hidden">
        <.flag_strip langs={@view.subtitle_languages} />
      </td>
      <td class="px-related py-2.5 align-middle w-px whitespace-nowrap [[data-browser][data-drawer=open]_&]:hidden">
        <.resolution_badge resolution={@view.resolution} />
      </td>
      <td class="px-related py-2.5 align-middle w-px whitespace-nowrap">
        <span class="text-xs text-text-subtle">
          {relative_time(@view.imported_at)}
        </span>
      </td>
    </tr>
    """
  end

  attr :id, :string, required: true
  attr :row, :map, required: true, doc: "raw Media struct from the stream"
  attr :selected, :boolean, default: false

  def card(assigns) do
    view = RowView.from_media(assigns.row)
    assigns = assign(assigns, :view, view)

    ~H"""
    <li
      id={@id}
      phx-click="open_drawer"
      phx-value-id={@view.id}
      class={[
        "flex flex-col gap-related rounded-card border border-border bg-surface p-cluster shadow-card",
        "transition-colors cursor-pointer hover:bg-surface-hover",
        @selected && "ring-2 ring-focus-ring border-border-focus"
      ]}
    >
      <div class="flex items-center gap-related min-w-0">
        <span class="grid size-9 shrink-0 place-items-center rounded-control border border-border-subtle bg-surface-inset text-text-muted">
          <.media_type_icon media_type={@view.media_type} class="size-icon-sm" />
        </span>
        <.file_name file_name={@view.file_name} class="text-sm font-medium text-text" />
      </div>

      <p class="truncate text-sm text-text-muted" title={matched_content_inline(@view)}>
        {matched_content_inline(@view)}
      </p>

      <div class="flex flex-wrap items-center gap-related text-xs text-text-subtle">
        <.resolution_badge resolution={@view.resolution} />
        <span :if={@view.audio_languages != []} class="flex items-center gap-tight">
          <Lucideicons.volume_2 class="size-icon-xs" />
          <.flag_strip langs={@view.audio_languages} />
        </span>
        <span :if={@view.subtitle_languages != []} class="flex items-center gap-tight">
          <Lucideicons.captions class="size-icon-xs" />
          <.flag_strip langs={@view.subtitle_languages} />
        </span>
        <span :if={@view.clubs != []} class="flex items-center gap-tight">
          <Lucideicons.library class="size-icon-xs" />
          <.clubs_avatars clubs={@view.clubs} />
        </span>
        <span class="ml-auto whitespace-nowrap">{relative_time(@view.imported_at)}</span>
      </div>
    </li>
    """
  end

  attr :clubs, :list, required: true

  defp clubs_avatars(%{clubs: []} = assigns) do
    ~H"""
    <span class="text-xs text-text-subtle">—</span>
    """
  end

  defp clubs_avatars(assigns) do
    ~H"""
    <.avatar_group avatars={@clubs} avatar_size="xs" />
    """
  end

  attr :langs, :list, required: true

  defp flag_strip(%{langs: []} = assigns) do
    ~H"""
    <span class="text-xs text-text-subtle">—</span>
    """
  end

  defp flag_strip(assigns) do
    ~H"""
    <div class="flex items-center gap-tight whitespace-nowrap">
      <span
        :for={lang <- Enum.take(@langs, 3)}
        title={lang}
        class="text-base leading-none"
      >
        {RowView.language_flag(lang)}
      </span>
      <span :if={length(@langs) > 3} class="text-xs text-text-subtle">
        +{length(@langs) - 3}
      </span>
    </div>
    """
  end

  attr :resolution, :atom, default: nil

  defp resolution_badge(%{resolution: nil} = assigns) do
    ~H"""
    <span class="text-xs text-text-subtle">—</span>
    """
  end

  defp resolution_badge(assigns) do
    ~H"""
    <.badge variant="muted" size="sm">{RowView.resolution_label(@resolution)}</.badge>
    """
  end

  defp matched_content_inline(%{content_title: nil}), do: "—"

  defp matched_content_inline(%{content_title: title, content_sub: nil}), do: title

  defp matched_content_inline(%{content_title: title, content_sub: sub}),
    do: "#{title} · #{sub}"

  defp relative_time(nil), do: "—"

  defp relative_time(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86_400)}d ago"
    end
  end

  defp relative_time(%NaiveDateTime{} = ndt) do
    case DateTime.from_naive(ndt, "Etc/UTC") do
      {:ok, dt} -> relative_time(dt)
      _ -> "—"
    end
  end
end
