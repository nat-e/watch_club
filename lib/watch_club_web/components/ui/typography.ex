defmodule WatchClubWeb.Components.UI.Typography do
  use Phoenix.Component

  attr :text, :string, required: true
  attr :class, :any, default: nil

  def text_label(assigns) do
    ~H"""
    <span class={["text-xs font-medium tracking-wide text-text-subtle uppercase", @class]}>
      {@text}
    </span>
    """
  end
end
