defmodule WatchClubWeb.UI.Button do
  @moduledoc """
  Token-driven Watch Club button primitive.
  """

  use Phoenix.Component

  attr :class, :any, default: nil

  attr :variant, :string,
    values: ~w(primary secondary ghost danger),
    default: "primary"

  attr :size, :string,
    values: ~w(sm md lg icon icon-sm),
    default: "md"

  attr :type, :string, values: ~w(button submit reset), default: "button"

  attr :rest, :global,
    include:
      ~w(disabled form name value autofocus href navigate patch method download replace target aria-label aria-busy)

  slot :icon do
    attr :position, :string, values: ~w(start end)
  end

  slot :inner_block

  def button(%{rest: rest, disabled: true})
      when is_map_key(rest, :href) or is_map_key(rest, :navigate) or is_map_key(rest, :patch) do
    raise ArgumentError, """
    <.button> cannot be both `disabled` and a link (href/navigate/patch).
    Use a real <button>, or conditionally render the link.
    """
  end

  def button(%{rest: rest} = assigns)
      when is_map_key(rest, :href) or is_map_key(rest, :navigate) or is_map_key(rest, :patch) do
    ~H"""
    <.link
      class={[
        "inline-flex shrink-0 items-center justify-center rounded-control border border-transparent bg-clip-padding text-sm font-semibold whitespace-nowrap transition-colors duration-150 outline-none select-none focus-visible:border-border-focus focus-visible:ring-2 focus-visible:ring-border-focus/40 disabled:pointer-events-none disabled:opacity-50 aria-busy:cursor-progress [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-icon",
        @variant == "primary" &&
          "bg-primary text-on-primary shadow-glow hover:bg-primary-hover active:bg-primary-active",
        @variant == "secondary" &&
          "border-border bg-surface-raised text-text hover:bg-surface-hover active:bg-surface-active",
        @variant == "ghost" &&
          "bg-transparent text-text-muted hover:bg-surface-hover hover:text-text active:bg-surface-active",
        @variant == "danger" &&
          "bg-danger text-on-danger hover:bg-danger/90 active:bg-danger/80 focus-visible:border-danger-border focus-visible:ring-danger/30",
        @size == "sm" && "h-control-sm gap-tight px-group text-xs",
        @size == "md" && "h-control-md gap-related px-group text-sm",
        @size == "lg" && "h-control-lg gap-related px-cluster text-base",
        @size == "icon" && "size-control-md p-0",
        @size == "icon-sm" && "size-control-sm p-0",
        @class
      ]}
      {@rest}
    >
      <span
        :for={icon <- @icon}
        :if={icon[:position] in [nil, "start"]}
        class="inline-flex shrink-0 items-center justify-center"
      >
        {render_slot(icon)}
      </span>
      {render_slot(@inner_block)}
      <span
        :for={icon <- @icon}
        :if={icon[:position] == "end"}
        class="inline-flex shrink-0 items-center justify-center"
      >
        {render_slot(icon)}
      </span>
    </.link>
    """
  end

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex shrink-0 items-center justify-center rounded-control border border-transparent bg-clip-padding text-sm font-semibold whitespace-nowrap transition-colors duration-150 outline-none select-none focus-visible:border-border-focus focus-visible:ring-2 focus-visible:ring-border-focus/40 disabled:pointer-events-none disabled:opacity-50 aria-busy:cursor-progress [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-icon",
        @variant == "primary" &&
          "bg-primary text-on-primary shadow-glow hover:bg-primary-hover active:bg-primary-active",
        @variant == "secondary" &&
          "border-border bg-surface-raised text-text hover:bg-surface-hover active:bg-surface-active",
        @variant == "ghost" &&
          "bg-transparent text-text-muted hover:bg-surface-hover hover:text-text active:bg-surface-active",
        @variant == "danger" &&
          "bg-danger text-on-danger hover:bg-danger/90 active:bg-danger/80 focus-visible:border-danger-border focus-visible:ring-danger/30",
        @size == "sm" && "h-control-sm gap-tight px-group text-xs",
        @size == "md" && "h-control-md gap-related px-group text-sm",
        @size == "lg" && "h-control-lg gap-related px-cluster text-base",
        @size == "icon" && "size-control-md p-0",
        @size == "icon-sm" && "size-control-sm p-0",
        @class
      ]}
      {@rest}
    >
      <span
        :for={icon <- @icon}
        :if={icon[:position] in [nil, "start"]}
        class="inline-flex shrink-0 items-center justify-center"
      >
        {render_slot(icon)}
      </span>
      {render_slot(@inner_block)}
      <span
        :for={icon <- @icon}
        :if={icon[:position] == "end"}
        class="inline-flex shrink-0 items-center justify-center"
      >
        {render_slot(icon)}
      </span>
    </button>
    """
  end
end
