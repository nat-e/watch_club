defmodule Shadcn.Storybook.Carousel do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Carousel

  def function, do: &Carousel.carousel/1

  def imports, do: [{Shadcn.Components.Card, [card: 1]}]

  defp container_template(content) do
    """
    <div class="flex w-[440px] justify-center p-10">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  defp slide(i, opts \\ []) do
    class_attr =
      case Keyword.get(opts, :class) do
        nil -> ""
        c -> ~s| class="#{c}"|
      end

    text_size = Keyword.get(opts, :text_size, "text-4xl")

    inner =
      if Keyword.get(opts, :aspect_square, true) do
        ~s|<div class="-m-6 flex aspect-square items-center justify-center p-6"><span class="#{text_size} font-semibold">#{i}</span></div>|
      else
        ~s|<div class="flex h-full items-center justify-center"><span class="#{text_size} font-semibold">#{i}</span></div>|
      end

    """
    <:slide#{class_attr}>
      <div class="p-1">
        <.card>
          #{inner}
        </.card>
      </div>
    </:slide>
    """
  end

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default — one full-width slide at a time",
        attributes: %{id: "car-default", class: "w-full max-w-xs"},
        slots: for(i <- 1..5, do: slide(i))
      },
      %Variation{
        id: :sizes,
        description: "Sizes — `basis` utilities show multiple slides at once",
        attributes: %{id: "car-sizes", class: "w-full max-w-sm"},
        slots:
          for(i <- 1..5, do: slide(i, class: "md:basis-1/2 lg:basis-1/3", text_size: "text-3xl"))
      },
      %Variation{
        id: :spacing,
        description: "Spacing — padding on each slide creates visible gutters",
        attributes: %{id: "car-spacing", class: "w-full max-w-sm"},
        slots:
          for(
            i <- 1..5,
            do: slide(i, class: "pl-4 md:basis-1/2 lg:basis-1/3", text_size: "text-2xl")
          )
      },
      %Variation{
        id: :vertical,
        description: "Vertical orientation",
        attributes: %{
          id: "car-vert",
          orientation: "vertical",
          class: "w-full max-w-xs h-[200px]"
        },
        slots:
          for(
            i <- 1..5,
            do:
              slide(i,
                class: "md:basis-1/2",
                text_size: "text-3xl",
                aspect_square: false
              )
          )
      },
      %Variation{
        id: :autoplay,
        description: "Autoplay — advances every 2s, loops, pauses on hover",
        attributes: %{
          id: "car-autoplay",
          class: "w-full max-w-xs",
          autoplay: 2000,
          loop: true
        },
        slots: for(i <- 1..5, do: slide(i))
      }
    ]
  end
end
