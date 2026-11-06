defmodule WatchClubWeb.Storybook.Button do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.Button

  def function, do: &Button.button/1

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{id: "button-default"},
        slots: ["Save changes"]
      },
      %VariationGroup{
        id: :variants,
        description: "Variants",
        variations: [
          %Variation{
            id: :primary,
            attributes: %{id: "button-primary", variant: "primary"},
            slots: ["Primary"]
          },
          %Variation{
            id: :accent,
            attributes: %{id: "button-accent", variant: "accent"},
            slots: ["Accent"]
          },
          %Variation{
            id: :secondary,
            attributes: %{id: "button-secondary", variant: "secondary"},
            slots: ["Secondary"]
          },
          %Variation{
            id: :ghost,
            attributes: %{id: "button-ghost", variant: "ghost"},
            slots: ["Ghost"]
          },
          %Variation{
            id: :overlay,
            description: "Over an image or a video",
            attributes: %{id: "button-overlay", variant: "overlay"},
            slots: ["Overlay"]
          },
          %Variation{
            id: :danger,
            attributes: %{id: "button-danger", variant: "danger"},
            slots: ["Delete"]
          }
        ]
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes",
        variations: [
          %Variation{id: :sm, attributes: %{id: "button-small", size: "sm"}, slots: ["Small"]},
          %Variation{id: :md, attributes: %{id: "button-medium", size: "md"}, slots: ["Medium"]},
          %Variation{id: :lg, attributes: %{id: "button-large", size: "lg"}, slots: ["Large"]}
        ]
      },
      %Variation{
        id: :with_icon,
        description: "With leading icon",
        attributes: %{id: "button-with-icon"},
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
            attributes: %{
              :id => "button-icon",
              :size => "icon",
              "aria-label" => "Add recommendation"
            },
            slots: [~s(<:icon><span aria-hidden="true">+</span></:icon>)]
          },
          %Variation{
            id: :icon_sm,
            attributes: %{
              :id => "button-icon-sm",
              :size => "icon-sm",
              "aria-label" => "Add recommendation"
            },
            slots: [~s(<:icon><span aria-hidden="true">+</span></:icon>)]
          }
        ]
      },
      %Variation{
        id: :disabled,
        description: "Disabled",
        attributes: %{id: "button-disabled", disabled: true},
        slots: ["Unavailable"]
      },
      %Variation{
        id: :link,
        description: "Rendered as a link when href/navigate/patch is passed",
        attributes: %{id: "button-link", href: "#", variant: "secondary"},
        slots: ["Open club"]
      }
    ]
  end
end
