defmodule Shadcn.Storybook.Command do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Command

  def function, do: &Command.command/1

  def imports,
    do: [
      {Lucideicons,
       [
         calendar: 1,
         smile: 1,
         calculator: 1,
         user: 1,
         credit_card: 1,
         settings: 1,
         file: 1,
         folder: 1,
         mail: 1,
         message_circle: 1,
         bell: 1,
         search: 1,
         star: 1,
         heart: 1,
         globe: 1,
         lock: 1,
         key: 1,
         shield: 1,
         tag: 1,
         tags: 1,
         bookmark: 1
       ]},
      {Shadcn.Components.Button, [button: 1]},
      {Shadcn.Components.Dialog, [dialog: 1]}
    ]

  def variations do
    [
      %VariationGroup{
        id: :default,
        description: "Dialog",
        template: """
        <.dialog id="cmd-dialog" show_close={false}>
          <:trigger><.button variant="outline">Open Command</.button></:trigger>
          <:title class="sr-only">Command Palette</:title>
          <:description class="sr-only">Search for a command to run.</:description>
          <.psb-variation/>
        </.dialog>
        """,
        variations: [
          %Variation{
            id: :default,
            attributes: %{id: "cmd-dialog-cmd", class: "border-0"},
            slots: groups_slots()
          }
        ]
      },
      %Variation{
        id: :basic,
        description: "Basic",
        attributes: %{id: "cmd-basic", class: "rounded-lg border shadow-md"},
        slots: [
          ~s|<:input placeholder="Type a command or search..." />|,
          ~s|<:item value="calendar"><Lucideicons.calendar /><span>Calendar</span></:item>|,
          ~s|<:item value="search-emoji"><Lucideicons.smile /><span>Search Emoji</span></:item>|,
          ~s|<:item value="calculator"><Lucideicons.calculator /><span>Calculator</span></:item>|,
          ~s|<:item value="profile"><Lucideicons.user /><span>Profile</span></:item>|,
          ~s|<:item value="settings"><Lucideicons.settings /><span>Settings</span></:item>|
        ]
      },
      %Variation{
        id: :shortcuts,
        description: "Shortcuts",
        attributes: %{id: "cmd-shortcuts", class: "rounded-lg border shadow-md"},
        slots: [
          ~s|<:input placeholder="Type a command or search..." />|,
          ~s|<:item value="profile" shortcut="⌘P"><Lucideicons.user /><span>Profile</span></:item>|,
          ~s|<:item value="billing" shortcut="⌘B"><Lucideicons.credit_card /><span>Billing</span></:item>|,
          ~s|<:item value="settings" shortcut="⌘S"><Lucideicons.settings /><span>Settings</span></:item>|,
          ~s|<:item value="notifications" shortcut="⌘N"><Lucideicons.bell /><span>Notifications</span></:item>|
        ]
      },
      %Variation{
        id: :groups,
        description: "Groups",
        attributes: %{id: "cmd-groups", class: "rounded-lg border shadow-md"},
        slots: groups_slots()
      },
      %Variation{
        id: :scrollable,
        description: "Scrollable",
        attributes: %{id: "cmd-scrollable", class: "rounded-lg border shadow-md"},
        slots: scrollable_slots()
      }
    ]
  end

  defp groups_slots do
    [
      ~s|<:input placeholder="Type a command or search..." />|,
      ~s|<:group heading="Suggestions" />|,
      ~s|<:item value="calendar" group="Suggestions"><Lucideicons.calendar /><span>Calendar</span></:item>|,
      ~s|<:item value="search-emoji" group="Suggestions"><Lucideicons.smile /><span>Search Emoji</span></:item>|,
      ~s|<:item value="calculator" group="Suggestions" disabled><Lucideicons.calculator /><span>Calculator</span></:item>|,
      ~s|<:group heading="Settings" />|,
      ~s|<:item value="profile" group="Settings" shortcut="⌘P"><Lucideicons.user /><span>Profile</span></:item>|,
      ~s|<:item value="billing" group="Settings" shortcut="⌘B"><Lucideicons.credit_card /><span>Billing</span></:item>|,
      ~s|<:item value="settings" group="Settings" shortcut="⌘S"><Lucideicons.settings /><span>Settings</span></:item>|
    ]
  end

  defp scrollable_slots do
    files = ~w(README CHANGELOG LICENSE Dockerfile package.json mix.exs config.exs)
    folders = ~w(src lib test docs assets priv build)
    contacts = ["Alice", "Bob", "Charlie", "Dana", "Eve", "Frank", "Grace", "Henry"]

    file_items =
      Enum.map(files, fn name ->
        ~s|<:item value="file-#{String.downcase(name)}" group="Files"><Lucideicons.file /><span>#{name}</span></:item>|
      end)

    folder_items =
      Enum.map(folders, fn name ->
        ~s|<:item value="folder-#{name}" group="Folders"><Lucideicons.folder /><span>#{name}</span></:item>|
      end)

    contact_items =
      Enum.map(contacts, fn name ->
        ~s|<:item value="contact-#{String.downcase(name)}" group="Contacts"><Lucideicons.user /><span>#{name}</span></:item>|
      end)

    [
      ~s|<:input placeholder="Type a command or search..." />|,
      ~s|<:group heading="Files" />|
    ] ++
      file_items ++
      [~s|<:group heading="Folders" />|] ++
      folder_items ++
      [~s|<:group heading="Contacts" />|] ++ contact_items
  end
end
