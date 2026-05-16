defmodule WatchClubWeb.Storybook.Kbd do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.Kbd

  def function, do: &Kbd.kbd/1
  def imports, do: [{WatchClubWeb.Components.UI.Kbd, [kbd_group: 1]}]

  defp container_template(content) do
    """
    <div class="flex items-center gap-3 p-4 text-text">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{id: :symbol, slots: ["⌘"]},
      %Variation{id: :letter, slots: ["K"]},
      %Variation{
        id: :group,
        description: "Keyboard shortcut group",
        template: """
        <.kbd_group>
          <.kbd>Ctrl</.kbd>
          <.kbd>+</.kbd>
          <.kbd>K</.kbd>
        </.kbd_group>
        """
      },
      %Variation{
        id: :command_palette,
        description: "Command palette shortcut",
        template: """
        <span class="inline-flex items-center gap-2 text-sm text-text-muted">
          Search
          <.kbd_group>
            <.kbd>⌘</.kbd>
            <.kbd>K</.kbd>
          </.kbd_group>
        </span>
        """
      }
    ]
  end
end
