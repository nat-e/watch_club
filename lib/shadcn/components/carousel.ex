defmodule Shadcn.Components.Carousel do
  @moduledoc """
  Horizontal slider for cycling through cards / images.

      <.carousel id="watches">
        <:slide :for={watch <- @watches}>
          <img src={watch.image} class="size-full object-cover" />
        </:slide>
      </.carousel>

  Built on native scroll-snap (no virtualization, no JS animation library).
  Prev/next buttons scroll the viewport by one slide width.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/carousel.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/carousel
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :orientation, :string, values: ~w(horizontal vertical), default: "horizontal"
  attr :autoplay, :integer, default: nil
  attr :loop, :boolean, default: false
  attr :rest, :global

  slot :slide, required: true do
    attr :class, :any
  end

  def carousel(assigns) do
    ~H"""
    <div
      id={@id}
      data-slot="carousel"
      data-orientation={@orientation}
      data-autoplay={@autoplay}
      data-loop={@loop && "true"}
      phx-hook="CarouselHook"
      class={["group/carousel", @class]}
      {@rest}
    >
      <div data-slot="carousel-viewport">
        <div data-slot="carousel-track">
          <div :for={s <- @slide} data-slot="carousel-slide" class={s[:class]}>
            {render_slot(s)}
          </div>
        </div>
      </div>
      <button
        type="button"
        data-slot="carousel-prev"
        aria-label="Previous slide"
      >
        <Lucideicons.chevron_left />
      </button>
      <button
        type="button"
        data-slot="carousel-next"
        aria-label="Next slide"
      >
        <Lucideicons.chevron_right />
      </button>
    </div>
    """
  end
end
