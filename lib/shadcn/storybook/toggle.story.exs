defmodule Shadcn.Storybook.Toggle do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Toggle

  def function, do: &Toggle.toggle/1
  def imports, do: [{Lucideicons, [bold: 1, italic: 1, underline: 1]}]

  def variations do
    [
      %Variation{
        id: :default,
        slots: ["<Lucideicons.bold />"]
      },
      %Variation{
        id: :pressed,
        attributes: %{pressed: true},
        slots: ["<Lucideicons.bold />"]
      },
      %Variation{
        id: :outline,
        attributes: %{variant: "outline"},
        slots: ["<Lucideicons.italic />"]
      },
      %Variation{
        id: :outline_pressed,
        attributes: %{variant: "outline", pressed: true},
        slots: ["<Lucideicons.italic />"]
      },
      %Variation{
        id: :with_text,
        slots: ["<Lucideicons.italic />", "Italic"]
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes",
        template: """
        <div class="flex items-center gap-2">
          <.psb-variation-group/>
        </div>
        """,
        variations:
          for s <- ~w(sm default lg) do
            %Variation{
              id: String.to_atom(s),
              attributes: %{size: s, variant: "outline"},
              slots: ["<Lucideicons.bold />"]
            }
          end
      },
      %Variation{
        id: :disabled,
        attributes: %{disabled: true},
        slots: ["<Lucideicons.bold />"]
      }
    ]
  end
end
