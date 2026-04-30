defmodule Shadcn.Storybook.ToggleGroup do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.ToggleGroup

  def function, do: &ToggleGroup.toggle_group/1
  def imports, do: [{Lucideicons, [bold: 1, italic: 1, underline: 1]}]

  @items [
    ~s(<:item value="bold"><Lucideicons.bold /></:item>),
    ~s(<:item value="italic"><Lucideicons.italic /></:item>),
    ~s(<:item value="underline"><Lucideicons.underline /></:item>)
  ]

  def variations do
    [
      %Variation{
        id: :default_single,
        attributes: %{value: "bold"},
        slots: @items
      },
      %Variation{
        id: :outline_single,
        attributes: %{variant: "outline", value: "italic"},
        slots: @items
      },
      %Variation{
        id: :multiple,
        description: "Multiple selection",
        attributes: %{type: "multiple", variant: "outline", value: ["bold", "italic"]},
        slots: @items
      },
      %Variation{
        id: :spaced,
        description: "Items with spacing",
        attributes: %{spacing: 2, variant: "outline", value: "bold"},
        slots: @items
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes",
        template: """
        <div class="flex items-start gap-4">
          <.psb-variation-group/>
        </div>
        """,
        variations:
          for s <- ~w(sm default lg) do
            %Variation{
              id: String.to_atom(s),
              attributes: %{size: s, variant: "outline", value: "bold"},
              slots: @items
            }
          end
      },
      %Variation{
        id: :vertical,
        description: "Vertical orientation",
        attributes: %{orientation: "vertical", variant: "outline", value: "bold"},
        slots: @items
      }
    ]
  end
end
