defmodule WatchClubWeb.Components.UI.Pill do
  @moduledoc """
  One of a row of rounded tabs, such as the seasons of Episodes: a filled pill for the current
  one, a quiet label for the others. A button, or a link that patches the page.
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :current, :boolean, required: true
  attr :patch, :string, default: nil, doc: "patches the page to it, instead of being a button"
  attr :replace, :boolean, default: false, doc: "replaces the page in the history, with `patch`"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def pill(%{patch: nil} = assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      aria-current={to_string(@current)}
      class={[
        "flex h-control-sm shrink-0 snap-start items-center rounded-full px-group text-sm font-semibold whitespace-nowrap transition-colors phx-click-loading:cursor-progress phx-click-loading:opacity-60",
        @current && "bg-surface-selected text-text",
        !@current && "text-text-muted hover:bg-surface-hover hover:text-text",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  def pill(assigns) do
    ~H"""
    <.link
      id={@id}
      patch={@patch}
      replace={@replace}
      aria-current={to_string(@current)}
      class={[
        "flex h-control-sm shrink-0 snap-start items-center rounded-full px-group text-sm font-semibold whitespace-nowrap transition-colors phx-click-loading:cursor-progress phx-click-loading:opacity-60",
        @current && "bg-surface-selected text-text",
        !@current && "text-text-muted hover:bg-surface-hover hover:text-text",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
