defmodule WatchClubWeb.UI.Empty do
  @moduledoc """
  Token-driven Watch Club empty-state primitive.
  """

  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global

  slot :icon do
    attr :class, :any
  end

  slot :title, required: true do
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
        "flex w-full min-w-0 flex-col items-center justify-center gap-4 rounded-card border border-dashed border-border-subtle bg-surface p-8 text-center text-balance",
        @class
      ]}
      {@rest}
    >
      <div
        :for={icon <- @icon}
        data-slot="empty-icon"
        class={[
          "flex size-12 shrink-0 items-center justify-center rounded-control border border-border bg-surface-raised text-text-muted [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-6",
          icon[:class]
        ]}
      >
        {render_slot(icon)}
      </div>

      <div data-slot="empty-header" class="grid max-w-sm gap-2">
        <h3
          :for={title <- @title}
          data-slot="empty-title"
          class={["text-lg font-semibold tracking-tight text-text", title[:class]]}
        >
          {render_slot(title)}
        </h3>

        <p
          :for={description <- @description}
          data-slot="empty-description"
          class={[
            "text-sm/relaxed text-text-muted [&_a]:underline [&_a]:underline-offset-4 [&_a]:hover:text-text",
            description[:class]
          ]}
        >
          {render_slot(description)}
        </p>
      </div>

      <div
        :if={@inner_block != []}
        data-slot="empty-content"
        class="flex w-full max-w-sm min-w-0 flex-col items-center gap-4 text-sm text-balance"
      >
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end
end
