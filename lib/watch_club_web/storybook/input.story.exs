defmodule WatchClubWeb.Storybook.Input do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.Input

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
        attributes: %{placeholder: "Search the Library"}
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
        id: :textarea,
        description: "Multi-line text box",
        attributes: %{type: "textarea", rows: 3, placeholder: "What happened?"}
      },
      %Variation{
        id: :custom_width,
        description: "Consumer classes can adjust layout",
        attributes: %{placeholder: "Playlist name", class: "sm:w-80"}
      }
    ]
  end
end
