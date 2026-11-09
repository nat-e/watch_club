defmodule WatchClubWeb.Admin.MediaBrowserPage.Filename do
  @moduledoc """
  Renders a filename with a middle-ellipsis: the head truncates with an
  ellipsis while the tail (extension + a few preceding characters) stays
  fully visible.
  """
  use Phoenix.Component

  @tail_len 12

  attr :file_name, :string, required: true
  attr :class, :any, default: nil

  def file_name(assigns) do
    {head, tail} = split(assigns.file_name)
    assigns = assigns |> assign(:head, head) |> assign(:tail, tail)

    ~H"""
    <span
      class={["flex min-w-0 overflow-hidden", @class]}
      title={@file_name}
    >
      <%!-- whitespace-pre keeps a space at the cut --%>
      <span class="overflow-hidden text-ellipsis whitespace-pre">{@head}</span>
      <span :if={@tail != ""} class="shrink-0 whitespace-pre">{@tail}</span>
    </span>
    """
  end

  defp split(name) do
    len = String.length(name)

    if len <= @tail_len + 4 do
      {name, ""}
    else
      {String.slice(name, 0, len - @tail_len), String.slice(name, len - @tail_len, @tail_len)}
    end
  end
end
