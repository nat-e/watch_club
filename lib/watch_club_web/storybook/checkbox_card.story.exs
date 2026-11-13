defmodule WatchClubWeb.Storybook.CheckboxCard do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.Checkbox

  def function, do: &Checkbox.checkbox_card/1

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
        description: "Checks a boolean form field",
        attributes: %{
          field: Phoenix.Component.to_form(%{"prefer_sdh?" => true}, as: :story)[:prefer_sdh?]
        },
        slots: [
          "Prefer subtitles for the deaf and hard of hearing (SDH)",
          "<:description>They also describe sounds and say who is speaking.</:description>"
        ]
      },
      %Variation{
        id: :without_description,
        description: "Label only",
        attributes: %{
          field: Phoenix.Component.to_form(%{"notify" => false}, as: :story)[:notify]
        },
        slots: ["Email me when a request is ready"]
      }
    ]
  end
end
