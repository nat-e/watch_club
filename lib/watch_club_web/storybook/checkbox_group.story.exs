defmodule WatchClubWeb.Storybook.CheckboxGroup do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.Checkbox

  def function, do: &Checkbox.checkbox_group/1

  def template do
    """
    <div class="w-full max-w-sm p-4 text-text">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :default,
        description: "Checks the options in the form field's list",
        attributes: %{
          field: Phoenix.Component.to_form(%{"languages" => ["en"]}, as: :story)[:languages],
          options: ["en", "fr"],
          to_value: &Function.identity/1
        },
        slots: [
          ~s|<:label :let={language}>{%{"en" => "English", "fr" => "French"}[language]}</:label>|
        ]
      },
      %Variation{
        id: :with_disabled,
        description: "Disabled option",
        attributes: %{
          field: Phoenix.Component.to_form(%{"days" => []}, as: :story)[:days],
          options: ["weekdays", "weekends"],
          to_value: &Function.identity/1,
          disabled?: &(&1 == "weekends")
        },
        slots: [~s|<:label :let={days}>{String.capitalize(days)}</:label>|]
      }
    ]
  end
end
