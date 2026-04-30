defmodule Shadcn.Storybook.NativeSelect do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.NativeSelect

  def function, do: &NativeSelect.native_select/1

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{name: "country"},
        slots: [
          ~s|<option value="">Select country</option>|,
          ~s|<option value="us">United States</option>|,
          ~s|<option value="ca">Canada</option>|,
          ~s|<option value="mx">Mexico</option>|
        ]
      },
      %Variation{
        id: :small,
        attributes: %{name: "tier", size: "sm"},
        slots: [
          ~s|<option value="free">Free</option>|,
          ~s|<option value="pro">Pro</option>|,
          ~s|<option value="enterprise">Enterprise</option>|
        ]
      },
      %Variation{
        id: :with_groups,
        description: "With option groups",
        attributes: %{name: "fruit"},
        slots: [
          ~s|<optgroup label="Citrus">|,
          ~s|<option value="lemon">Lemon</option>|,
          ~s|<option value="lime">Lime</option>|,
          ~s|</optgroup>|,
          ~s|<optgroup label="Berries">|,
          ~s|<option value="blueberry">Blueberry</option>|,
          ~s|<option value="raspberry">Raspberry</option>|,
          ~s|</optgroup>|
        ]
      },
      %Variation{
        id: :disabled,
        attributes: %{name: "country", disabled: true},
        slots: [
          ~s|<option value="us">United States</option>|
        ]
      }
    ]
  end
end
