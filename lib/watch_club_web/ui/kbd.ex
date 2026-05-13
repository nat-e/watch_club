defmodule WatchClubWeb.UI.Kbd do
  @moduledoc """
  Token-driven Watch Club keyboard shortcut primitives.
  """

  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def kbd(assigns) do
    ~H"""
    <kbd
      data-slot="kbd"
      class={[
        "pointer-events-none inline-flex h-6 min-w-6 items-center justify-center gap-1 rounded-control border border-border-subtle bg-surface-inset px-2 font-sans text-sm font-medium text-text-muted select-none [&_svg:not([class*='size-'])]:size-3.5",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </kbd>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def kbd_group(assigns) do
    ~H"""
    <span data-slot="kbd-group" class={["inline-flex items-center gap-1", @class]} {@rest}>
      {render_slot(@inner_block)}
    </span>
    """
  end
end
