defmodule Shadcn.Storybook.RadioGroup do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.RadioGroup

  def function, do: &RadioGroup.radio_group/1

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{name: "plan", value: "pro"},
        slots: [
          ~s(<:item value="free">Free</:item>),
          ~s(<:item value="pro">Pro</:item>),
          ~s(<:item value="enterprise">Enterprise</:item>)
        ]
      },
      %Variation{
        id: :empty,
        description: "Nothing selected",
        attributes: %{name: "size"},
        slots: [
          ~s(<:item value="sm">Small</:item>),
          ~s(<:item value="md">Medium</:item>),
          ~s(<:item value="lg">Large</:item>)
        ]
      },
      %Variation{
        id: :with_disabled,
        description: "Disabled item",
        attributes: %{name: "tier", value: "basic"},
        slots: [
          ~s(<:item value="basic">Basic</:item>),
          ~s|<:item value="pro" disabled>Pro (coming soon)</:item>|,
          ~s(<:item value="team">Team</:item>)
        ]
      }
    ]
  end
end
