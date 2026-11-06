defmodule WatchClubWeb.Components.UI.FilterChip do
  @moduledoc """
  A filter people turn on or off: an outlined pill with its icon and label, tinted pink once it's
  on, without a check mark.
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :on, :boolean, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  slot :icon
  slot :inner_block, required: true

  def filter_chip(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      aria-pressed={to_string(@on)}
      data-on={@on}
      class={[
        "inline-flex h-control-sm shrink-0 items-center gap-tight rounded-full border border-border-control px-group text-sm font-semibold whitespace-nowrap text-text-muted transition-colors not-data-on:hover:bg-surface-hover not-data-on:hover:text-text [&_svg]:size-icon-sm [&_svg]:shrink-0",
        "data-on:border-primary-border data-on:bg-primary-bg data-on:text-primary",
        @class
      ]}
      {@rest}
    >
      {render_slot(@icon)}
      {render_slot(@inner_block)}
    </button>
    """
  end
end
