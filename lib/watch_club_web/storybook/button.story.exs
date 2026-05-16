defmodule WatchClubWeb.Storybook.Button do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.Button

  def function, do: &Button.button/1

  def variations do
    [
      %Variation{
        id: :default,
        slots: ["Save changes"]
      },
      %VariationGroup{
        id: :variants,
        description: "Variants",
        variations: [
          %Variation{id: :primary, attributes: %{variant: "primary"}, slots: ["Primary"]},
          %Variation{id: :accent, attributes: %{variant: "accent"}, slots: ["Accent"]},
          %Variation{id: :secondary, attributes: %{variant: "secondary"}, slots: ["Secondary"]},
          %Variation{id: :ghost, attributes: %{variant: "ghost"}, slots: ["Ghost"]},
          %Variation{id: :danger, attributes: %{variant: "danger"}, slots: ["Delete"]}
        ]
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes",
        variations: [
          %Variation{id: :sm, attributes: %{size: "sm"}, slots: ["Small"]},
          %Variation{id: :md, attributes: %{size: "md"}, slots: ["Medium"]},
          %Variation{id: :lg, attributes: %{size: "lg"}, slots: ["Large"]}
        ]
      },
      %Variation{
        id: :with_icon,
        description: "With leading icon",
        slots: [
          ~s(<:icon><span aria-hidden="true">+</span></:icon>),
          "New recommendation"
        ]
      },
      %VariationGroup{
        id: :icon_sizes,
        description: "Icon-only sizes",
        variations: [
          %Variation{
            id: :icon,
            attributes: %{:size => "icon", "aria-label" => "Add recommendation"},
            slots: [~s(<:icon><span aria-hidden="true">+</span></:icon>)]
          },
          %Variation{
            id: :icon_sm,
            attributes: %{:size => "icon-sm", "aria-label" => "Add recommendation"},
            slots: [~s(<:icon><span aria-hidden="true">+</span></:icon>)]
          }
        ]
      },
      %Variation{
        id: :disabled,
        description: "Disabled",
        attributes: %{disabled: true},
        slots: ["Unavailable"]
      },
      %Variation{
        id: :link,
        description: "Rendered as a link when href/navigate/patch is passed",
        attributes: %{href: "#", variant: "secondary"},
        slots: ["Open club"]
      }
    ]
  end
end
