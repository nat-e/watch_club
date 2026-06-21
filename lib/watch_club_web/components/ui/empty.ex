defmodule WatchClubWeb.Components.UI.Empty do
  @moduledoc """
  Token-driven Watch Club empty-state primitive.
  """

  use Phoenix.Component

  attr :class, :any, default: nil

  attr :border, :boolean,
    default: true,
    doc: "renders the default bordered surface and icon frame"

  attr :size, :string,
    values: ~w(default sm),
    default: "default",
    doc: "controls the empty state's spacing and typography density"

  attr :rest, :global

  slot :icon do
    attr :class, :any
  end

  slot :title do
    attr :class, :any
  end

  slot :description do
    attr :class, :any
  end

  slot :inner_block

  def empty(assigns) do
    ~H"""
    <section
      data-slot="empty"
      class={[
        "flex w-full min-w-0 flex-col items-center justify-center rounded-xl text-center text-balance",
        @size == "default" && "gap-group p-cluster",
        @size == "sm" && "gap-related p-group",
        @border && "border border-dashed border-border-subtle bg-surface",
        !@border && "bg-transparent",
        @class
      ]}
      {@rest}
    >
      <div
        :for={icon <- @icon}
        data-slot="empty-icon"
        class={[
          "flex shrink-0 items-center justify-center rounded-md text-text-muted [&_svg]:pointer-events-none [&_svg]:shrink-0",
          @size == "default" && "size-control-lg [&_svg:not([class*='size-'])]:size-icon-lg",
          @size == "sm" && "size-control-sm [&_svg:not([class*='size-'])]:size-icon",
          @border && "border border-border bg-surface-raised",
          !@border && "bg-transparent",
          icon[:class]
        ]}
      >
        {render_slot(icon)}
      </div>

      <div
        data-slot="empty-header"
        class={[
          "grid max-w-sm",
          @size == "default" && "gap-related",
          @size == "sm" && "gap-tight"
        ]}
      >
        <h3
          :for={title <- @title}
          data-slot="empty-title"
          class={[
            "font-semibold tracking-tight text-text",
            @size == "default" && "text-lg",
            @size == "sm" && "text-md",
            title[:class]
          ]}
        >
          {render_slot(title)}
        </h3>

        <p
          :for={description <- @description}
          data-slot="empty-description"
          class={[
            "text-text-muted [&_a]:underline [&_a]:underline-offset-4 [&_a]:hover:text-text",
            @size == "default" && "text-sm/relaxed",
            @size == "sm" && "text-sm/relaxed",
            description[:class]
          ]}
        >
          {render_slot(description)}
        </p>
      </div>

      <div
        :if={@inner_block != []}
        data-slot="empty-content"
        class={[
          "flex w-full max-w-sm min-w-0 flex-col items-center text-balance",
          @size == "default" && "gap-group text-sm",
          @size == "sm" && "gap-related text-sm"
        ]}
      >
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end
end
