defmodule Shadcn.Storybook.Menubar do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Menubar

  def function, do: &Menubar.menubar/1

  def imports,
    do: [
      {Shadcn.Components.Menubar,
       [
         menubar_checkbox_item: 1,
         menubar_group: 1,
         menubar_item: 1,
         menubar_menu: 1,
         menubar_radio_group: 1,
         menubar_radio_item: 1,
         menubar_separator: 1,
         menubar_shortcut: 1,
         menubar_sub: 1
       ]},
      {Lucideicons,
       [
         circle_help: 1,
         file: 1,
         folder: 1,
         save: 1,
         settings: 1,
         trash: 1
       ]}
    ]

  defp container_template(content) do
    """
    <div class="flex min-h-[360px] items-start justify-center p-6">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :demo,
        description: "Full menubar with sub-menus, checkboxes, radio group",
        attributes: %{class: "w-72"},
        slots: [
          """
          <.menubar_menu trigger="File">
            <.menubar_group>
              <.menubar_item>New Tab <.menubar_shortcut>⌘T</.menubar_shortcut></.menubar_item>
              <.menubar_item>New Window <.menubar_shortcut>⌘N</.menubar_shortcut></.menubar_item>
              <.menubar_item disabled>New Incognito Window</.menubar_item>
            </.menubar_group>
            <.menubar_separator />
            <.menubar_group>
              <.menubar_sub>
                <:trigger>Share</:trigger>
                <.menubar_group>
                  <.menubar_item>Email link</.menubar_item>
                  <.menubar_item>Messages</.menubar_item>
                  <.menubar_item>Notes</.menubar_item>
                </.menubar_group>
              </.menubar_sub>
            </.menubar_group>
            <.menubar_separator />
            <.menubar_group>
              <.menubar_item>Print... <.menubar_shortcut>⌘P</.menubar_shortcut></.menubar_item>
            </.menubar_group>
          </.menubar_menu>
          """,
          """
          <.menubar_menu trigger="Edit">
            <.menubar_group>
              <.menubar_item>Undo <.menubar_shortcut>⌘Z</.menubar_shortcut></.menubar_item>
              <.menubar_item>Redo <.menubar_shortcut>⇧⌘Z</.menubar_shortcut></.menubar_item>
            </.menubar_group>
            <.menubar_separator />
            <.menubar_group>
              <.menubar_sub>
                <:trigger>Find</:trigger>
                <.menubar_group>
                  <.menubar_item>Search the web</.menubar_item>
                </.menubar_group>
                <.menubar_separator />
                <.menubar_group>
                  <.menubar_item>Find...</.menubar_item>
                  <.menubar_item>Find Next</.menubar_item>
                  <.menubar_item>Find Previous</.menubar_item>
                </.menubar_group>
              </.menubar_sub>
            </.menubar_group>
            <.menubar_separator />
            <.menubar_group>
              <.menubar_item>Cut</.menubar_item>
              <.menubar_item>Copy</.menubar_item>
              <.menubar_item>Paste</.menubar_item>
            </.menubar_group>
          </.menubar_menu>
          """,
          """
          <.menubar_menu trigger="View">
            <.menubar_group>
              <.menubar_checkbox_item>Bookmarks Bar</.menubar_checkbox_item>
              <.menubar_checkbox_item checked>Full URLs</.menubar_checkbox_item>
            </.menubar_group>
            <.menubar_separator />
            <.menubar_group>
              <.menubar_item inset>Reload <.menubar_shortcut>⌘R</.menubar_shortcut></.menubar_item>
              <.menubar_item disabled inset>Force Reload <.menubar_shortcut>⇧⌘R</.menubar_shortcut></.menubar_item>
            </.menubar_group>
            <.menubar_separator />
            <.menubar_group>
              <.menubar_item inset>Toggle Fullscreen</.menubar_item>
            </.menubar_group>
            <.menubar_separator />
            <.menubar_group>
              <.menubar_item inset>Hide Sidebar</.menubar_item>
            </.menubar_group>
          </.menubar_menu>
          """,
          """
          <.menubar_menu trigger="Profiles">
            <.menubar_radio_group value="benoit">
              <.menubar_radio_item value="andy">Andy</.menubar_radio_item>
              <.menubar_radio_item value="benoit" checked>Benoit</.menubar_radio_item>
              <.menubar_radio_item value="luis">Luis</.menubar_radio_item>
            </.menubar_radio_group>
            <.menubar_separator />
            <.menubar_group>
              <.menubar_item inset>Edit...</.menubar_item>
            </.menubar_group>
            <.menubar_separator />
            <.menubar_group>
              <.menubar_item inset>Add Profile...</.menubar_item>
            </.menubar_group>
          </.menubar_menu>
          """
        ]
      },
      %Variation{
        id: :checkbox,
        description: "Checkbox items in two menus",
        attributes: %{class: "w-72"},
        slots: [
          """
          <.menubar_menu trigger="View">
            <.menubar_checkbox_item>Always Show Bookmarks Bar</.menubar_checkbox_item>
            <.menubar_checkbox_item checked>Always Show Full URLs</.menubar_checkbox_item>
            <.menubar_separator />
            <.menubar_item inset>Reload <.menubar_shortcut>⌘R</.menubar_shortcut></.menubar_item>
            <.menubar_item disabled inset>Force Reload <.menubar_shortcut>⇧⌘R</.menubar_shortcut></.menubar_item>
          </.menubar_menu>
          """,
          """
          <.menubar_menu trigger="Format">
            <.menubar_checkbox_item checked>Strikethrough</.menubar_checkbox_item>
            <.menubar_checkbox_item>Code</.menubar_checkbox_item>
            <.menubar_checkbox_item>Superscript</.menubar_checkbox_item>
          </.menubar_menu>
          """
        ]
      },
      %Variation{
        id: :radio,
        description: "Radio groups for single-selection",
        attributes: %{class: "w-72"},
        slots: [
          """
          <.menubar_menu trigger="Profiles">
            <.menubar_radio_group value="benoit">
              <.menubar_radio_item value="andy">Andy</.menubar_radio_item>
              <.menubar_radio_item value="benoit" checked>Benoit</.menubar_radio_item>
              <.menubar_radio_item value="luis">Luis</.menubar_radio_item>
            </.menubar_radio_group>
            <.menubar_separator />
            <.menubar_item inset>Edit...</.menubar_item>
            <.menubar_item inset>Add Profile...</.menubar_item>
          </.menubar_menu>
          """,
          """
          <.menubar_menu trigger="Theme">
            <.menubar_radio_group value="system">
              <.menubar_radio_item value="light">Light</.menubar_radio_item>
              <.menubar_radio_item value="dark">Dark</.menubar_radio_item>
              <.menubar_radio_item value="system" checked>System</.menubar_radio_item>
            </.menubar_radio_group>
          </.menubar_menu>
          """
        ]
      },
      %Variation{
        id: :submenu,
        description: "Nested submenus",
        attributes: %{class: "w-72"},
        slots: [
          """
          <.menubar_menu trigger="File">
            <.menubar_sub>
              <:trigger>Share</:trigger>
              <.menubar_item>Email link</.menubar_item>
              <.menubar_item>Messages</.menubar_item>
              <.menubar_item>Notes</.menubar_item>
            </.menubar_sub>
            <.menubar_separator />
            <.menubar_item>Print... <.menubar_shortcut>⌘P</.menubar_shortcut></.menubar_item>
          </.menubar_menu>
          """,
          """
          <.menubar_menu trigger="Edit">
            <.menubar_item>Undo <.menubar_shortcut>⌘Z</.menubar_shortcut></.menubar_item>
            <.menubar_item>Redo <.menubar_shortcut>⇧⌘Z</.menubar_shortcut></.menubar_item>
            <.menubar_separator />
            <.menubar_sub>
              <:trigger>Find</:trigger>
              <.menubar_item>Find...</.menubar_item>
              <.menubar_item>Find Next</.menubar_item>
              <.menubar_item>Find Previous</.menubar_item>
            </.menubar_sub>
            <.menubar_separator />
            <.menubar_item>Cut</.menubar_item>
            <.menubar_item>Copy</.menubar_item>
            <.menubar_item>Paste</.menubar_item>
          </.menubar_menu>
          """
        ]
      },
      %Variation{
        id: :icons,
        description: "Items with leading icons + destructive variant",
        attributes: %{class: "w-72"},
        slots: [
          """
          <.menubar_menu trigger="File">
            <.menubar_item>
              <Lucideicons.file />
              New File <.menubar_shortcut>⌘N</.menubar_shortcut>
            </.menubar_item>
            <.menubar_item>
              <Lucideicons.folder />
              Open Folder
            </.menubar_item>
            <.menubar_separator />
            <.menubar_item>
              <Lucideicons.save />
              Save <.menubar_shortcut>⌘S</.menubar_shortcut>
            </.menubar_item>
          </.menubar_menu>
          """,
          """
          <.menubar_menu trigger="More">
            <.menubar_group>
              <.menubar_item>
                <Lucideicons.settings />
                Settings
              </.menubar_item>
              <.menubar_item>
                <Lucideicons.circle_help />
                Help
              </.menubar_item>
              <.menubar_separator />
              <.menubar_item variant="destructive">
                <Lucideicons.trash />
                Delete
              </.menubar_item>
            </.menubar_group>
          </.menubar_menu>
          """
        ]
      }
    ]
  end
end
