defmodule WatchClubWeb.Storybook.DesignSystem.Badge do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.UI.Badges

  def function, do: &Badges.badge/1
  def imports, do: [{Lucideicons, [check: 1, circle_alert: 1]}]

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
          <.psb-variation-group />
        </div>
        """,
        variations: [
          %Variation{id: :default, attributes: %{variant: "default"}, slots: ["Default"]},
          %Variation{id: :secondary, attributes: %{variant: "secondary"}, slots: ["Secondary"]},
          %Variation{id: :success, attributes: %{variant: "success"}, slots: ["Success"]},
          %Variation{id: :muted, attributes: %{variant: "muted"}, slots: ["Muted"]},
          %Variation{id: :danger, attributes: %{variant: "danger"}, slots: ["Danger"]}
        ]
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes",
        template: """
        <div class="flex items-center gap-2">
          <.psb-variation-group />
        </div>
        """,
        variations: [
          %Variation{id: :sm, attributes: %{size: "sm"}, slots: ["Small"]},
          %Variation{id: :md, attributes: %{size: "md"}, slots: ["Default"]}
        ]
      },
      %Variation{
        id: :with_icon,
        description: "With icon",
        slots: [
          "<:icon><Lucideicons.check /></:icon>",
          "Verified"
        ]
      },
      %Variation{
        id: :danger_with_icon,
        description: "Danger with icon",
        attributes: %{variant: "danger"},
        slots: [
          "<:icon><Lucideicons.circle_alert /></:icon>",
          "Error"
        ]
      }
    ]
  end
end
