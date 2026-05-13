defmodule WatchClubWeb.Storybook.DesignSystem.Label do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.UI.Label

  def function, do: &Label.label/1

  def imports, do: [{WatchClubWeb.UI.Input, [input: 1]}]

  defp container_template(content) do
    """
    <div class="grid w-full max-w-sm gap-2 p-4 text-text">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{for: "email"},
        slots: ["Email"]
      },
      %Variation{
        id: :with_input,
        description: "Label paired with an input",
        template: """
        <.label for="club-name">Club name</.label>
        <.input id="club-name" name="club_name" placeholder="Friday movie night" />
        """
      },
      %Variation{
        id: :disabled,
        description: "Disabled state via a disabled field group",
        template: """
        <div class="group grid gap-2" data-disabled="true">
          <.label for="disabled-email">Email</.label>
          <.input id="disabled-email" name="email" placeholder="name@example.com" disabled />
        </div>
        """
      }
    ]
  end
end
