defmodule WatchClubWeb.Storybook.DesignSystem.Input do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.UI.Input

  def function, do: &Input.input/1

  defp container_template(content) do
    """
    <div class="w-full max-w-md p-4">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default text input",
        attributes: %{placeholder: "Search the club"}
      },
      %Variation{
        id: :email,
        description: "Email input",
        attributes: %{type: "email", placeholder: "name@example.com", autocomplete: "email"}
      },
      %Variation{
        id: :disabled,
        description: "Disabled input",
        attributes: %{placeholder: "Unavailable", disabled: true}
      },
      %Variation{
        id: :invalid,
        description: "Input with validation state",
        attributes: %{placeholder: "Required", errors: ["Required"]}
      },
      %Variation{
        id: :file,
        description: "File input",
        attributes: %{type: "file"}
      },
      %Variation{
        id: :custom_width,
        description: "Consumer classes can adjust layout",
        attributes: %{placeholder: "Club name", class: "sm:w-80"}
      }
    ]
  end
end
