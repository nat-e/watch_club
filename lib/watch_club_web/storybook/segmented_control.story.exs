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
          ~s(<:item selected={true}>Create account</:item>),
          ~s(<:item>Sign in</:item>)
        ]
      },
      %Variation{
        id: :sign_in_selected,
        attributes: %{"aria-label" => "Account action"},
        slots: [
          ~s(<:item>Create account</:item>),
          ~s(<:item selected={true}>Sign in</:item>)
        ]
      },
      %Variation{
        id: :links,
        description: "Items can navigate with href/navigate/patch attributes.",
        attributes: %{"aria-label" => "Invitation account action"},
        slots: [
          ~s(<:item href="#" selected={true}>Create account</:item>),
          ~s(<:item href="#">Sign in</:item>)
        ]
      }
    ]
  end
end
