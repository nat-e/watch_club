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

  attr :text, :string, required: true

  @doc "The sentence that opens a page, under the app bar that shows its name."
  def page_description(assigns) do
    ~H"""
    <p class="max-w-readable text-base leading-7 text-text-muted">{@text}</p>
    """
  end
end
