defmodule Shadcn.Storybook.Kbd do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Kbd

  def function, do: &Kbd.kbd/1
  def imports, do: [{Shadcn.Components.Kbd, [kbd_group: 1]}]

  def variations do
    [
      %Variation{
        id: :default,
        slots: ["⌘"]
      },
      %Variation{
        id: :letter,
        slots: ["K"]
      },
      %Variation{
        id: :group,
        description: "Group of keys",
        template: """
        <.kbd_group>
          <.kbd>Ctrl</.kbd>
          <.kbd>+</.kbd>
          <.kbd>K</.kbd>
        </.kbd_group>
        """
      },
      %Variation{
        id: :group_command,
        description: "Command palette shortcut",
        template: """
        <.kbd_group>
          <.kbd>⌘</.kbd>
          <.kbd>K</.kbd>
        </.kbd_group>
        """
      }
    ]
  end
end
