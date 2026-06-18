defmodule WatchClubWeb.Components.UI.Typography do
  use Phoenix.Component

  attr :text, :string, required: true

  def text_label(assigns) do
    ~H"""
    <span class="text-xs font-medium tracking-wide text-text-muted uppercase">
      {@text}
    </span>
    """
  end
end
