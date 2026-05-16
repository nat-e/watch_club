defmodule WatchClubWeb.Components.UI.Alert do
  @moduledoc """
  Token-driven Watch Club alert/callout primitive.
  """

  use Phoenix.Component

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(default info warning danger), default: "default"
  attr :rest, :global

  slot :icon

  slot :title do
    attr :class, :any
  end

  slot :action do
    attr :class, :any
  end

  slot :inner_block, required: true

  def alert(assigns) do
    ~H"""
    <div
      role="alert"
      class={[
        "relative grid w-full gap-tight rounded-control border px-group py-related text-left text-sm",
        @icon != [] && "grid-cols-[auto_1fr] gap-x-related",
        @action != [] && "pr-18",
        @variant == "default" && "border-border bg-surface text-text",
        @variant == "info" && "border-info-border bg-info-bg text-info",
        @variant == "warning" && "border-warning-border bg-warning-bg text-warning",
        @variant == "danger" && "border-danger-border bg-danger-bg text-danger",
        @class
      ]}
      {@rest}
    >
      <span
        :for={icon <- @icon}
        class="row-span-2 mt-0.5 text-current [&_svg:not([class*='size-'])]:size-icon"
      >
        {render_slot(icon)}
      </span>

      <div
        :for={title <- @title}
        class={[
          "font-semibold leading-none text-balance [&_a]:underline [&_a]:underline-offset-4",
          title[:class]
        ]}
      >
        {render_slot(title)}
      </div>

      <div class="text-sm/relaxed text-balance opacity-90 [&_a]:underline [&_a]:underline-offset-4 [&_p:not(:last-child)]:mb-group">
        {render_slot(@inner_block)}
      </div>

      <div :for={action <- @action} class={["absolute top-3 right-3", action[:class]]}>
        {render_slot(action)}
      </div>
    </div>
    """
  end
end
