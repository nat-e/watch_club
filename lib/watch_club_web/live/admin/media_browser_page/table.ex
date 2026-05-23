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

  def render(assigns) do
    ~H"""
    <.table class="min-w-full">
      <.table_header>
        <.table_row>
          <.table_head>File</.table_head>
          <.table_head>Matched Content</.table_head>
          <.table_head class="w-[7rem]">Clubs</.table_head>
          <.table_head class="w-[6rem]">Audio</.table_head>
          <.table_head class="w-[6rem]">Subtitles</.table_head>
          <.table_head class="w-[5rem]">Resolution</.table_head>
          <.table_head class="w-[5rem]">Imported</.table_head>
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
    """
  end
end
