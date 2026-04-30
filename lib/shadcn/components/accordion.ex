defmodule Shadcn.Components.Accordion do
  @moduledoc """
  Vertical stack of headers that reveal content when expanded.

      <.accordion>
        <:item id="a" trigger="Is it accessible?">
          Yes. It uses semantic HTML and follows WAI-ARIA practices.
        </:item>
        <:item id="b" trigger="Is it styled?">
          Yes. It comes with default styles you can override.
        </:item>
      </.accordion>

      <.accordion type="single">
        <:item id="a" trigger="Single mode">
          Only one item can be open at a time.
        </:item>
        <:item id="b" trigger="Try opening me">
          Opening me closes the others.
        </:item>
      </.accordion>

  Built on native `<details>`. For `type="single"`, every item shares the
  same `name` attribute, which the browser uses to enforce one-open-at-a-
  time without any JS.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/accordion.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/accordion
  Radix doc: https://www.radix-ui.com/primitives/docs/components/accordion
  """
  use Phoenix.Component

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :type, :string, values: ~w(single multiple), default: "multiple"
  attr :rest, :global

  slot :item, required: true do
    attr :id, :string, required: true
    attr :trigger, :string, required: true
    attr :open, :boolean
    attr :disabled, :boolean
    attr :class, :any
  end

  def accordion(assigns) do
    assigns =
      assigns
      |> assign_new(:id, fn -> "accordion-#{System.unique_integer([:positive])}" end)

    ~H"""
    <div id={@id} data-slot="accordion" class={@class} {@rest}>
      <details
        :for={item <- @item}
        data-slot="accordion-item"
        data-disabled={item[:disabled] && ""}
        name={if @type == "single", do: @id, else: nil}
        open={item[:open]}
        class={item[:class]}
      >
        <summary
          data-slot="accordion-trigger"
          class="group/accordion-trigger"
          data-disabled={item[:disabled] && ""}
          aria-disabled={item[:disabled] && "true"}
          tabindex={item[:disabled] && "-1"}
        >
          <span data-slot="accordion-trigger-text">{item.trigger}</span>
          <Lucideicons.chevron_down data-slot="accordion-trigger-icon" />
        </summary>
        <div data-slot="accordion-content">
          {render_slot(item)}
        </div>
      </details>
    </div>
    """
  end
end
