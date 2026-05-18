defmodule WatchClubWeb.Storybook.SegmentedControl do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.SegmentedControl

  def function, do: &SegmentedControl.segmented_control/1

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{"aria-label" => "Account action"},
        slots: [
          ~s(<:item id="segmented-default-create-account-button" selected={true}>Create account</:item>),
          ~s(<:item id="segmented-default-sign-in-button">Sign in</:item>)
        ]
      },
      %Variation{
        id: :sign_in_selected,
        attributes: %{"aria-label" => "Account action"},
        slots: [
          ~s(<:item id="segmented-sign-in-create-account-button">Create account</:item>),
          ~s(<:item id="segmented-sign-in-selected-button" selected={true}>Sign in</:item>)
        ]
      },
      %Variation{
        id: :links,
        description: "Items can navigate with href/navigate/patch attributes.",
        attributes: %{"aria-label" => "Invitation account action"},
        slots: [
          ~s(<:item id="segmented-links-create-account-link" href="#" selected={true}>Create account</:item>),
          ~s(<:item id="segmented-links-sign-in-link" href="#">Sign in</:item>)
        ]
      }
    ]
  end
end
