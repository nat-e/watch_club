defmodule WatchClubWeb.Components.UI.Button do
  @moduledoc """
  Token-driven Watch Club button primitive.
  """

  use Phoenix.Component

  # The attributes that make the button a link
  @link_attributes ~w(href navigate patch method download replace target)a

  attr :id, :string, required: true
  attr :class, :any, default: nil

  attr :variant, :string,
    values: ~w(primary accent secondary ghost danger),
    default: "primary"

  attr :size, :string,
    values: ~w(sm md lg icon-sm icon icon-lg),
    default: "md"

  attr :type, :string, values: ~w(button submit reset), default: "button"
  attr :emphasis, :boolean, default: false, doc: "Adds rare brand glow emphasis."

  attr :rest, :global,
    include:
      ~w(disabled form name value autofocus aria-label aria-busy aria-pressed) ++
        Enum.map(@link_attributes, &Atom.to_string/1)

  slot :icon do
    attr :position, :string, values: ~w(start end)
  end

  slot :inner_block

  # A link can't be disabled, so a disabled link renders as a disabled native button.
  def button(%{rest: %{disabled: true} = rest} = assigns)
      when is_map_key(rest, :href) or is_map_key(rest, :navigate) or is_map_key(rest, :patch) do
    assigns
    |> assign(:rest, Map.drop(rest, @link_attributes))
    |> button()
  end

  def button(%{rest: rest} = assigns)
      when is_map_key(rest, :href) or is_map_key(rest, :navigate) or is_map_key(rest, :patch) do
    ~H"""
    <.link
      id={@id}
      class={class(@variant, @size, @emphasis) ++ [@class]}
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
      class={class(@variant, @size, @emphasis) ++ [@class]}
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

  defp class(variant, size, emphasis) do
    [
      "inline-flex items-center justify-center rounded-control border bg-clip-padding font-semibold whitespace-nowrap transition duration-150 select-none disabled:pointer-events-none disabled:cursor-not-allowed active:shadow-none disabled:opacity-40 disabled:shadow-none aria-busy:cursor-progress [&_svg]:shrink-0",
      variant == "primary" &&
        "border-transparent bg-primary text-on-primary hover:bg-primary-hover active:bg-primary-active",
      variant == "primary" && emphasis && "shadow-glow",
      variant == "accent" &&
        "border-accent-border bg-accent-bg text-accent hover:border-accent hover:text-accent-hover active:border-accent-border active:text-accent",
      variant == "secondary" &&
        "border-border bg-surface-raised text-text hover:bg-surface-hover active:bg-surface-active",
      variant == "ghost" &&
        "border-transparent bg-transparent text-text-muted hover:bg-surface-hover hover:text-text active:bg-surface-active",
      variant == "danger" &&
        "border-transparent bg-danger text-on-danger hover:bg-danger-hover active:bg-danger-active",
      size == "sm" &&
        "h-control-sm gap-tight px-group text-xs [&_svg:not([class*='size-'])]:size-icon",
      size == "md" &&
        "h-control-md gap-related px-group text-sm [&_svg:not([class*='size-'])]:size-icon",
      size == "lg" &&
        "h-control-lg gap-related px-cluster text-base [&_svg:not([class*='size-'])]:size-icon",
      size == "icon-sm" && "size-control-sm [&_svg:not([class*='size-'])]:size-icon-sm",
      size == "icon" && "size-control-md [&_svg:not([class*='size-'])]:size-icon",
      size == "icon-lg" && "size-control-lg [&_svg:not([class*='size-'])]:size-icon-lg"
    ]
  end
end
