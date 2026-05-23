defmodule WatchClubWeb.Admin.MediaBrowserPage.Table do
  @moduledoc """
  Table head + streamed rows for the Admin Media browser. Delegates the
  row body to `MediaRow`.
  """
  use WatchClubWeb, :html

  import WatchClubWeb.Components.UI.Table

  alias WatchClubWeb.Admin.MediaBrowserPage.MediaRow

  attr :streams, :map, required: true
  attr :selected_id, :any, default: nil
  attr :drawer_open?, :boolean, default: false

  def render(assigns) do
    ~H"""
    <!--
      data-drawer drives the column-hiding via the Tailwind variant
      `[[data-browser][data-drawer=open]_&]:hidden` on the cells below.
      Done in CSS rather than :if so stream rows don't need to re-render
      when the drawer toggles.
    -->
    <div
      data-browser
      data-drawer={(@drawer_open? && "open") || "closed"}
      class="min-w-0"
    >
      <ul
        id="media-cards-list"
        phx-update="stream"
        class="flex flex-col gap-related lg:hidden"
      >
        <MediaRow.card
          :for={{dom_id, row} <- @streams.media_cards}
          id={dom_id}
          row={row}
          selected={@selected_id == row.id}
        />
      </ul>

      <div class="hidden lg:block">
        <.table>
          <.table_header>
            <.table_row>
              <.table_head class="text-left w-full max-w-0 overflow-hidden">File</.table_head>
              <.table_head class="text-left max-w-[20rem]">Matched</.table_head>
              <.table_head class="w-px text-left [[data-browser][data-drawer=open]_&]:hidden">Clubs</.table_head>
              <.table_head class="w-px text-left [[data-browser][data-drawer=open]_&]:hidden">Audio</.table_head>
              <.table_head class="w-px text-left [[data-browser][data-drawer=open]_&]:hidden">Subs</.table_head>
              <.table_head class="w-px text-left [[data-browser][data-drawer=open]_&]:hidden">Res</.table_head>
              <.table_head class="w-px text-left">Imported</.table_head>
            </.table_row>
          </.table_header>
          <tbody id="media-rows-tbody" phx-update="stream">
            <MediaRow.row
              :for={{dom_id, row} <- @streams.media_rows}
              id={dom_id}
              row={row}
              selected={@selected_id == row.id}
            />
          </tbody>
        </.table>
      </div>
    </div>
    """
  end
end
