defmodule Shadcn.Storybook.Button do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Button

  def function, do: &Button.button/1
  def imports, do: [{Lucideicons, [plus: 1, refresh_cw: 1]}]

  @meta Button.__components__().button
  @variants Enum.find(@meta.attrs, &(&1.name == :variant)).opts[:values]
  @sizes Enum.find(@meta.attrs, &(&1.name == :size)).opts[:values]

  def variations do
    [
      %Variation{
        id: :default,
        slots: ["Save"]
      },
      %VariationGroup{
        id: :variants,
        description: "Variants",
        variations:
          for v <- @variants do
            %Variation{
              id: String.to_atom(v),
              attributes: %{variant: v},
              slots: [String.capitalize(v)]
            }
          end
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes",
        variations:
          for s <- @sizes, not String.starts_with?(s, "icon") do
            %Variation{
              id: String.to_atom(s),
              attributes: %{size: s},
              slots: [s]
            }
          end
      },
      %VariationGroup{
        id: :icon_sizes,
        description: "Icon-only sizes",
        variations:
          for s <- @sizes, String.starts_with?(s, "icon") do
            %Variation{
              id: String.to_atom(s),
              attributes: %{size: s, variant: "outline"},
              slots: ["<:icon><Lucideicons.plus /></:icon>"]
            }
          end
      },
      %Variation{
        id: :leading_icon,
        description: "With leading icon",
        slots: [
          ~s(<:icon position="start"><Lucideicons.plus /></:icon>),
          "New item"
        ]
      },
      %Variation{
        id: :loading,
        description: "Loading state",
        attributes: %{disabled: true},
        slots: [
          ~s(<:icon position="end"><Lucideicons.refresh_cw class="animate-spin" /></:icon>),
          "Saving..."
        ]
      },
      %Variation{
        id: :disabled,
        description: "Disabled",
        attributes: %{disabled: true},
        slots: ["Can't click"]
      }
    ]
  end
end
