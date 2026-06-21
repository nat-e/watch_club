defmodule WatchClubWeb.Components.UI.Button do
  @moduledoc """
  Token-driven Watch Club button primitive.
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil

  attr :variant, :string,
    values: ~w(primary accent secondary ghost danger),
    default: "primary"

  attr :size, :string,
    values: ~w(sm md lg icon icon-sm),
    default: "md"

  attr :type, :string, values: ~w(button submit reset), default: "button"
  attr :emphasis, :boolean, default: false, doc: "Adds rare brand glow emphasis."

  attr :selected, :boolean,
    default: false,
    doc: "Applies the selected neutral surface state to neutral button variants."

  attr :rest, :global,
    include:
      ~w(disabled form name value autofocus href navigate patch method download replace target aria-label aria-busy aria-pressed)

  slot :icon do
    attr :position, :string, values: ~w(start end)
  end

  slot :inner_block

  def button(%{rest: rest, disabled: true})
      when is_map_key(rest, :href) or is_map_key(rest, :navigate) or is_map_key(rest, :patch) do
    raise ArgumentError, """
    Button cannot be both `disabled` and a link (href/navigate/patch).
    Use a native button element, or conditionally render the link.
    """
  end

  def button(%{rest: rest} = assigns)
      when is_map_key(rest, :href) or is_map_key(rest, :navigate) or is_map_key(rest, :patch) do
    ~H"""
    <.link
      id={@id}
      class={class(@variant, @size, @selected, @emphasis) ++ [@class]}
      {@rest}
    >
      <.inner icon={@icon}>{render_slot(@inner_block)}</.inner>
    </.link>
    """
  end

  def button(assigns) do
    ~H"""
    <button
      id={@id}
      type={@type}
      class={class(@variant, @size, @selected, @emphasis) ++ [@class]}
      {@rest}
    >
      <.inner icon={@icon}>{render_slot(@inner_block)}</.inner>
    </button>
    """
  end

  defp inner(assigns) do
    ~H"""
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
    """
  end

  defp class(variant, size, selected, emphasis) do
    [
      "inline-flex items-center justify-center rounded-md border bg-clip-padding font-semibold whitespace-nowrap transition duration-150 outline-none select-none focus-visible:ring-1 disabled:cursor-not-allowed active:shadow-none disabled:opacity-75 disabled:shadow-none aria-busy:cursor-progress [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-icon",
      variant == "primary" &&
        "border-transparent bg-primary text-on-primary hover:bg-primary-hover active:bg-primary-active focus-visible:ring-primary-ring",
      variant == "primary" && emphasis && "shadow-glow",
      variant == "accent" &&
        "border-transparent bg-accent text-on-accent hover:bg-accent-hover active:bg-accent-active focus-visible:ring-accent-ring",
      variant == "secondary" && !selected &&
        "border-border bg-surface-raised text-text hover:bg-surface-hover active:bg-surface-active focus-visible:ring-ring",
      variant == "secondary" && selected &&
        "border-border bg-surface-selected text-text hover:bg-surface-selected active:bg-surface-selected",
      variant == "ghost" && !selected &&
        "border-transparent bg-transparent text-text-muted hover:bg-surface-hover hover:text-text active:bg-surface-active",
      variant == "ghost" && selected &&
        "border-transparent bg-surface-selected text-text hover:bg-surface-selected active:bg-surface-selected",
      variant == "danger" &&
        "border-transparent bg-danger text-on-danger hover:bg-danger-hover active:bg-danger-active focus-visible:border-danger-border focus-visible:ring-danger-ring",
      size == "sm" && "h-control-sm gap-tight px-group text-xs",
      size == "md" && "h-control-md gap-related px-group text-sm",
      size == "lg" && "h-control-lg gap-related px-cluster text-base",
      size == "icon" && "size-control-md p-0 text-sm",
      size == "icon-sm" && "size-control-sm p-0 text-sm"
    ]
  end
end
