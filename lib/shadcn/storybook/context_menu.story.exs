defmodule Shadcn.Storybook.ContextMenu do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.ContextMenu

  def function, do: &ContextMenu.context_menu/1

  def imports,
    do: [
      {Shadcn.Components.ContextMenu,
       [
         context_menu_checkbox_item: 1,
         context_menu_group: 1,
         context_menu_item: 1,
         context_menu_label: 1,
         context_menu_radio_group: 1,
         context_menu_radio_item: 1,
         context_menu_separator: 1,
         context_menu_shortcut: 1,
         context_menu_sub: 1
       ]},
      {Lucideicons,
       [
         archive: 1,
         clipboard_paste: 1,
         copy: 1,
         pencil: 1,
         scissors: 1,
         share: 1,
         trash_2: 1
       ]}
    ]

  defp container_template(content) do
    """
    <div class="flex min-h-[260px] items-center justify-center p-12">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  @trigger """
  <:trigger>
    <div class="flex h-[150px] w-[300px] items-center justify-center rounded-md border border-dashed text-sm">
      Right click here
    </div>
  </:trigger>
  """

  def variations do
    [
      %Variation{
        id: :basic,
        description: "A simple context menu with a few actions",
        attributes: %{id: "ctx-basic"},
        slots: [
          @trigger,
          """
          <.context_menu_group>
            <.context_menu_item>Back</.context_menu_item>
            <.context_menu_item disabled>Forward</.context_menu_item>
            <.context_menu_item>Reload</.context_menu_item>
          </.context_menu_group>
          """
        ]
      },
      %Variation{
        id: :submenu,
        description: "Use context_menu_sub to nest secondary actions",
        attributes: %{id: "ctx-submenu"},
        slots: [
          @trigger,
          """
          <.context_menu_group>
            <.context_menu_item>
              Copy
              <.context_menu_shortcut>⌘C</.context_menu_shortcut>
            </.context_menu_item>
            <.context_menu_item>
              Cut
              <.context_menu_shortcut>⌘X</.context_menu_shortcut>
            </.context_menu_item>
          </.context_menu_group>
          <.context_menu_sub>
            <:trigger>More Tools</:trigger>
            <.context_menu_group>
              <.context_menu_item>Save Page...</.context_menu_item>
              <.context_menu_item>Create Shortcut...</.context_menu_item>
              <.context_menu_item>Name Window...</.context_menu_item>
            </.context_menu_group>
            <.context_menu_separator />
            <.context_menu_group>
              <.context_menu_item>Developer Tools</.context_menu_item>
            </.context_menu_group>
            <.context_menu_separator />
            <.context_menu_group>
              <.context_menu_item variant="destructive">Delete</.context_menu_item>
            </.context_menu_group>
          </.context_menu_sub>
          """
        ]
      },
      %Variation{
        id: :shortcuts,
        description: "Add context_menu_shortcut to show keyboard hints",
        attributes: %{id: "ctx-shortcuts"},
        slots: [
          @trigger,
          """
          <.context_menu_group>
            <.context_menu_item>
              Back
              <.context_menu_shortcut>⌘[</.context_menu_shortcut>
            </.context_menu_item>
            <.context_menu_item disabled>
              Forward
              <.context_menu_shortcut>⌘]</.context_menu_shortcut>
            </.context_menu_item>
            <.context_menu_item>
              Reload
              <.context_menu_shortcut>⌘R</.context_menu_shortcut>
            </.context_menu_item>
          </.context_menu_group>
          <.context_menu_separator />
          <.context_menu_group>
            <.context_menu_item>
              Save
              <.context_menu_shortcut>⌘S</.context_menu_shortcut>
            </.context_menu_item>
            <.context_menu_item>
              Save As...
              <.context_menu_shortcut>⇧⌘S</.context_menu_shortcut>
            </.context_menu_item>
          </.context_menu_group>
          """
        ]
      },
      %Variation{
        id: :groups,
        description: "Group related actions and separate them with dividers",
        attributes: %{id: "ctx-groups"},
        slots: [
          @trigger,
          """
          <.context_menu_group>
            <.context_menu_label>File</.context_menu_label>
            <.context_menu_item>
              New File
              <.context_menu_shortcut>⌘N</.context_menu_shortcut>
            </.context_menu_item>
            <.context_menu_item>
              Open File
              <.context_menu_shortcut>⌘O</.context_menu_shortcut>
            </.context_menu_item>
            <.context_menu_item>
              Save
              <.context_menu_shortcut>⌘S</.context_menu_shortcut>
            </.context_menu_item>
          </.context_menu_group>
          <.context_menu_separator />
          <.context_menu_group>
            <.context_menu_label>Edit</.context_menu_label>
            <.context_menu_item>
              Undo
              <.context_menu_shortcut>⌘Z</.context_menu_shortcut>
            </.context_menu_item>
            <.context_menu_item>
              Redo
              <.context_menu_shortcut>⇧⌘Z</.context_menu_shortcut>
            </.context_menu_item>
            <.context_menu_separator />
            <.context_menu_item>
              Cut
              <.context_menu_shortcut>⌘X</.context_menu_shortcut>
            </.context_menu_item>
            <.context_menu_item>
              Copy
              <.context_menu_shortcut>⌘C</.context_menu_shortcut>
            </.context_menu_item>
            <.context_menu_item>
              Paste
              <.context_menu_shortcut>⌘V</.context_menu_shortcut>
            </.context_menu_item>
          </.context_menu_group>
          <.context_menu_separator />
          <.context_menu_group>
            <.context_menu_item variant="destructive">
              Delete
              <.context_menu_shortcut>⌫</.context_menu_shortcut>
            </.context_menu_item>
          </.context_menu_group>
          """
        ]
      },
      %Variation{
        id: :icons,
        description: "Combine icons with labels for quick scanning",
        attributes: %{id: "ctx-icons"},
        slots: [
          @trigger,
          """
          <.context_menu_group>
            <.context_menu_item><Lucideicons.copy />Copy</.context_menu_item>
            <.context_menu_item><Lucideicons.scissors />Cut</.context_menu_item>
            <.context_menu_item><Lucideicons.clipboard_paste />Paste</.context_menu_item>
          </.context_menu_group>
          <.context_menu_separator />
          <.context_menu_group>
            <.context_menu_item variant="destructive">
              <Lucideicons.trash_2 />Delete
            </.context_menu_item>
          </.context_menu_group>
          """
        ]
      },
      %Variation{
        id: :checkboxes,
        description: "Use context_menu_checkbox_item for toggles",
        attributes: %{id: "ctx-checkboxes"},
        slots: [
          @trigger,
          """
          <.context_menu_group>
            <.context_menu_checkbox_item checked>Show Bookmarks Bar</.context_menu_checkbox_item>
            <.context_menu_checkbox_item>Show Full URLs</.context_menu_checkbox_item>
            <.context_menu_checkbox_item>Show Developer Tools</.context_menu_checkbox_item>
          </.context_menu_group>
          """
        ]
      },
      %Variation{
        id: :radio,
        description: "Use context_menu_radio_item for exclusive choices",
        attributes: %{id: "ctx-radio"},
        slots: [
          @trigger,
          """
          <.context_menu_group>
            <.context_menu_label>People</.context_menu_label>
            <.context_menu_radio_group value="pedro">
              <.context_menu_radio_item value="pedro" checked>Pedro Duarte</.context_menu_radio_item>
              <.context_menu_radio_item value="colm">Colm Tuite</.context_menu_radio_item>
            </.context_menu_radio_group>
          </.context_menu_group>
          <.context_menu_separator />
          <.context_menu_group>
            <.context_menu_label>Theme</.context_menu_label>
            <.context_menu_radio_group value="light">
              <.context_menu_radio_item value="light" checked>Light</.context_menu_radio_item>
              <.context_menu_radio_item value="dark">Dark</.context_menu_radio_item>
              <.context_menu_radio_item value="system">System</.context_menu_radio_item>
            </.context_menu_radio_group>
          </.context_menu_group>
          """
        ]
      },
      %Variation{
        id: :destructive,
        description: ~s|Use variant="destructive" to style the menu item as destructive|,
        attributes: %{id: "ctx-destructive"},
        slots: [
          @trigger,
          """
          <.context_menu_group>
            <.context_menu_item><Lucideicons.pencil />Edit</.context_menu_item>
            <.context_menu_item><Lucideicons.share />Share</.context_menu_item>
          </.context_menu_group>
          <.context_menu_separator />
          <.context_menu_group>
            <.context_menu_item><Lucideicons.archive />Archive</.context_menu_item>
            <.context_menu_item variant="destructive">
              <Lucideicons.trash_2 />Delete
            </.context_menu_item>
          </.context_menu_group>
          """
        ]
      }
    ]
  end
end
