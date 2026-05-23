defmodule WatchClubWeb.Admin.MediaBrowserPage.Filename do
  @moduledoc """
  Renders a filename with a middle-ellipsis: the head truncates with an
  ellipsis while the tail (extension + a few preceding characters) stays
  fully visible. Shared by the table row, mobile card, and drawer hero.
  """
  use Phoenix.Component

  alias WatchClubWeb.Admin.MediaBrowserPage.RowView

  attr :file_name, :string, required: true
  attr :class, :any, default: nil
  attr :wrap, :boolean, default: false, doc: "wrap onto multiple lines instead of middle-truncating"

  def file_name(%{wrap: true} = assigns) do
    ~H"""
    <span class={["block break-all", @class]} title={@file_name}>
      {@file_name}
    </span>
    """
  end

  def file_name(assigns) do
    {head, tail} = RowView.split_file_name(assigns.file_name)
    assigns = assigns |> assign(:head, head) |> assign(:tail, tail)

    ~H"""
    <span
      class={["flex min-w-0 overflow-hidden", @class]}
      title={@file_name}
    >
      <span class="truncate">{@head}</span>
      <span :if={@tail != ""} class="shrink-0 whitespace-pre">{@tail}</span>
    </span>
    """
  end
end
