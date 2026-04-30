defmodule Shadcn.Storybook.Badge do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Badge

  def function, do: &Badge.badge/1
  def imports, do: [{Lucideicons, [check: 1, circle_alert: 1]}]

  @meta Badge.__components__().badge
  @variants Enum.find(@meta.attrs, &(&1.name == :variant)).opts[:values]

  def variations do
    [
      %Variation{
        id: :default,
        slots: ["Badge"]
      },
      %VariationGroup{
        id: :variants,
        description: "Variants",
        template: """
        <div class="flex flex-wrap items-center gap-2">
          <.psb-variation-group/>
        </div>
        """,
        variations:
          for v <- @variants do
            %Variation{
              id: String.to_atom(v),
              attributes: %{variant: v},
              slots: [String.capitalize(v)]
            }
          end
      },
      %Variation{
        id: :with_icon,
        description: "With icon",
        slots: [
          "<Lucideicons.check />",
          "Verified"
        ]
      },
      %Variation{
        id: :destructive_with_icon,
        description: "Destructive with icon",
        attributes: %{variant: "destructive"},
        slots: [
          "<Lucideicons.circle_alert />",
          "Error"
        ]
      },
      %Variation{
        id: :as_link,
        description: "As link (hover styles activate)",
        attributes: %{variant: "outline", href: "#"},
        slots: ["5 unread"]
      }
    ]
  end
end
