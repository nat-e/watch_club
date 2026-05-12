defmodule WatchClubWeb.UI.Button do
  @moduledoc """
  Token-driven Watch Club button primitive.
  """

  use Phoenix.Component

  @base_class "inline-flex shrink-0 items-center justify-center rounded-control border border-transparent bg-clip-padding text-sm font-semibold whitespace-nowrap transition-colors duration-150 outline-none select-none focus-visible:border-border-focus focus-visible:ring-2 focus-visible:ring-border-focus/40 disabled:pointer-events-none disabled:opacity-50 aria-busy:cursor-progress [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-icon"
  @icon_class "inline-flex shrink-0 items-center justify-center"

  @variant_classes %{
    "primary" =>
      "bg-primary text-on-primary shadow-glow hover:bg-primary-hover active:bg-primary-active",
    "secondary" =>
      "border-border bg-surface-raised text-text hover:bg-surface-hover active:bg-surface-active",
    "ghost" =>
      "bg-transparent text-text-muted hover:bg-surface-hover hover:text-text active:bg-surface-active",
    "danger" =>
      "bg-danger text-on-danger hover:bg-danger/90 active:bg-danger/80 focus-visible:border-danger-border focus-visible:ring-danger/30"
  }

  @size_classes %{
    "sm" => "h-control-sm gap-1.5 px-3 text-xs",
    "md" => "h-control-md gap-2 px-4 text-sm",
    "lg" => "h-control-lg gap-2.5 px-5 text-base",
    "icon" => "size-control-md p-0",
    "icon-sm" => "size-control-sm p-0"
  }

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
    assigns = assign(assigns, :classes, button_classes(assigns))

    ~H"""
    <.link
      data-slot="wc-button"
      data-variant={@variant}
      data-size={@size}
      class={@classes}
      {@rest}
    >
      <.button_content icon={@icon}>
        {render_slot(@inner_block)}
      </.button_content>
    </.link>
    """
  end

  def button(assigns) do
    assigns = assign(assigns, :classes, button_classes(assigns))

    ~H"""
    <button
      type={@type}
      data-slot="wc-button"
      data-variant={@variant}
      data-size={@size}
      class={@classes}
      {@rest}
    >
      <.button_content icon={@icon}>
        {render_slot(@inner_block)}
      </.button_content>
    </button>
    """
  end

  defp button_content(assigns) do
    assigns = assign(assigns, :icon_class, @icon_class)

    ~H"""
    <span
      :for={icon <- @icon}
      :if={icon[:position] in [nil, "start"]}
      data-slot="wc-button-icon"
      data-position="start"
      class={@icon_class}
    >
      {render_slot(icon)}
    </span>
    {render_slot(@inner_block)}
    <span
      :for={icon <- @icon}
      :if={icon[:position] == "end"}
      data-slot="wc-button-icon"
      data-position="end"
      class={@icon_class}
    >
      {render_slot(icon)}
    </span>
    """
  end

  defp button_classes(assigns) do
    [
      @base_class,
      Map.fetch!(@variant_classes, assigns.variant),
      Map.fetch!(@size_classes, assigns.size),
      assigns.class
    ]
  end
end
