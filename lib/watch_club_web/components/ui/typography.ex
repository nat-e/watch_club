defmodule WatchClubWeb.Components.UI.Typography do
  use Phoenix.Component

  attr :text, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  def text_label(assigns) do
    ~H"""
    <span class={["text-xs font-semibold tracking-wider text-text-subtle uppercase", @class]} {@rest}>
      {@text}
    </span>
    """
  end
end
