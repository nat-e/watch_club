defmodule WatchClubWeb.Components.UI.Badge do
  @moduledoc """
  Token-driven Watch Club badges.
  """

  use Phoenix.Component

  attr :class, :any, default: nil

  attr :variant, :string,
    values: ~w(default accent secondary success muted danger),
    default: "default"

  attr :size, :string, values: ~w(sm md lg), default: "md"

  attr :rest, :global

  slot :icon do
    attr :class, :any
  end

  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex w-fit shrink-0 items-center justify-center gap-tight overflow-hidden rounded-full border font-medium whitespace-nowrap",
        @size == "sm" && "px-related py-0.5 text-xs",
        @size == "md" && "px-related py-0.5 text-sm",
        @size == "lg" && "px-related py-tight text-sm",
        @variant == "default" && "border-transparent bg-primary text-on-primary",
        @variant == "accent" && "border-transparent bg-accent text-on-accent",
        @variant == "secondary" && "border-border bg-surface-raised text-text",
        @variant == "success" && "border-success-border bg-success-bg text-success",
        @variant == "muted" && "border-border-subtle bg-surface-inset text-text-muted",
        @variant == "danger" && "border-danger-border bg-danger-bg text-danger",
        @class
      ]}
      {@rest}
    >
      <span
        :for={icon <- @icon}
        class={[
          "inline-flex shrink-0 items-center justify-center [&_svg]:pointer-events-none",
          @size == "sm" && "[&_svg]:size-3",
          @size == "md" && "[&_svg]:size-3.5",
          icon[:class]
        ]}
      >
        {render_slot(icon)}
      </span>
      {render_slot(@inner_block)}
    </span>
    """
  end
end
