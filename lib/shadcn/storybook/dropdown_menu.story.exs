defmodule Shadcn.Storybook.DropdownMenu do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.DropdownMenu

  def function, do: &DropdownMenu.dropdown_menu/1

  def imports,
    do: [
      {Shadcn.Components.Button, [button: 1]},
      {Shadcn.Components.DropdownMenu,
       [
         dropdown_menu_checkbox_item: 1,
         dropdown_menu_group: 1,
         dropdown_menu_item: 1,
         dropdown_menu_label: 1,
         dropdown_menu_radio_group: 1,
         dropdown_menu_radio_item: 1,
         dropdown_menu_separator: 1,
         dropdown_menu_shortcut: 1,
         dropdown_menu_sub: 1
       ]},
      {Lucideicons, [user: 1, settings: 1, log_out: 1, plus: 1, mail: 1]}
    ]

  defp container_template(content) do
    """
    <div class="flex min-h-[320px] items-start justify-center p-12">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  @sample_items [
    ~s(<.dropdown_menu_label>My Account</.dropdown_menu_label>),
    ~s(<.dropdown_menu_separator />),
    ~s(<.dropdown_menu_item>Profile</.dropdown_menu_item>),
    ~s(<.dropdown_menu_item>Billing</.dropdown_menu_item>),
    ~s(<.dropdown_menu_item>Settings</.dropdown_menu_item>)
  ]

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{id: "dm-default"},
        slots: [
          ~s(<:trigger><.button variant="outline">Open</.button></:trigger>),
          ~s(<.dropdown_menu_label>My Account</.dropdown_menu_label>),
          ~s(<.dropdown_menu_separator />),
          ~s(<.dropdown_menu_item>Profile<.dropdown_menu_shortcut>⌘P</.dropdown_menu_shortcut></.dropdown_menu_item>),
          ~s(<.dropdown_menu_item>Billing<.dropdown_menu_shortcut>⌘B</.dropdown_menu_shortcut></.dropdown_menu_item>),
          ~s(<.dropdown_menu_item>Settings<.dropdown_menu_shortcut>⌘S</.dropdown_menu_shortcut></.dropdown_menu_item>),
          ~s(<.dropdown_menu_separator />),
          ~s(<.dropdown_menu_item variant="destructive">Sign out<.dropdown_menu_shortcut>⌘Q</.dropdown_menu_shortcut></.dropdown_menu_item>)
        ]
      },
      %Variation{
        id: :with_icons,
        description: "Items with leading icons",
        attributes: %{id: "dm-icons"},
        slots: [
          ~s(<:trigger><.button variant="outline">Account</.button></:trigger>),
          ~s(<.dropdown_menu_item><Lucideicons.user />Profile</.dropdown_menu_item>),
          ~s(<.dropdown_menu_item><Lucideicons.settings />Settings</.dropdown_menu_item>),
          ~s(<.dropdown_menu_separator />),
          ~s(<.dropdown_menu_item variant="destructive"><Lucideicons.log_out />Sign out</.dropdown_menu_item>)
        ]
      },
      %Variation{
        id: :inset,
        description: "Inset items align past where an icon would sit",
        attributes: %{id: "dm-inset"},
        slots: [
          ~s(<:trigger><.button variant="outline">View</.button></:trigger>),
          ~s(<.dropdown_menu_label inset>Appearance</.dropdown_menu_label>),
          ~s(<.dropdown_menu_item inset>Comfortable</.dropdown_menu_item>),
          ~s(<.dropdown_menu_item inset>Compact</.dropdown_menu_item>)
        ]
      },
      %Variation{
        id: :checkbox_items,
        description: "Checkbox items",
        attributes: %{id: "dm-checkbox"},
        slots: [
          ~s(<:trigger><.button variant="outline">View options</.button></:trigger>),
          ~s(<.dropdown_menu_label>Panels</.dropdown_menu_label>),
          ~s(<.dropdown_menu_separator />),
          ~s(<.dropdown_menu_checkbox_item checked>Status bar</.dropdown_menu_checkbox_item>),
          ~s(<.dropdown_menu_checkbox_item>Activity bar</.dropdown_menu_checkbox_item>),
          ~s(<.dropdown_menu_checkbox_item checked>Panel</.dropdown_menu_checkbox_item>)
        ]
      },
      %Variation{
        id: :radio_group,
        description: "Radio group selection",
        attributes: %{id: "dm-radio"},
        slots: [
          ~s(<:trigger><.button variant="outline">People</.button></:trigger>),
          ~s(<.dropdown_menu_label>Assign to</.dropdown_menu_label>),
          ~s(<.dropdown_menu_separator />),
          """
          <.dropdown_menu_radio_group value="alice">
            <.dropdown_menu_radio_item value="alice" checked>Alice</.dropdown_menu_radio_item>
            <.dropdown_menu_radio_item value="bob">Bob</.dropdown_menu_radio_item>
            <.dropdown_menu_radio_item value="carol">Carol</.dropdown_menu_radio_item>
          </.dropdown_menu_radio_group>
          """
        ]
      },
      %Variation{
        id: :groups,
        description: "Multiple groups separated by dividers",
        attributes: %{id: "dm-groups"},
        slots: [
          ~s(<:trigger><.button variant="outline">My Account</.button></:trigger>),
          """
          <.dropdown_menu_group>
            <.dropdown_menu_label>My Account</.dropdown_menu_label>
            <.dropdown_menu_item>Profile</.dropdown_menu_item>
            <.dropdown_menu_item>Billing</.dropdown_menu_item>
            <.dropdown_menu_item>Settings</.dropdown_menu_item>
          </.dropdown_menu_group>
          """,
          ~s(<.dropdown_menu_separator />),
          """
          <.dropdown_menu_group>
            <.dropdown_menu_label>Team</.dropdown_menu_label>
            <.dropdown_menu_item>Invite users</.dropdown_menu_item>
            <.dropdown_menu_item>New Team</.dropdown_menu_item>
          </.dropdown_menu_group>
          """,
          ~s(<.dropdown_menu_separator />),
          ~s(<.dropdown_menu_item variant="destructive">Sign out</.dropdown_menu_item>)
        ]
      },
      %Variation{
        id: :submenu,
        description: "Submenu (matches the React reference example)",
        attributes: %{id: "dm-submenu"},
        slots: [
          ~s(<:trigger><.button variant="outline">Open</.button></:trigger>),
          """
          <.dropdown_menu_group>
            <.dropdown_menu_item>Team</.dropdown_menu_item>
            <.dropdown_menu_sub>
              <:trigger>Invite users</:trigger>
              <.dropdown_menu_item><Lucideicons.mail />Email</.dropdown_menu_item>
              <.dropdown_menu_item>Message</.dropdown_menu_item>
              <.dropdown_menu_sub>
                <:trigger>More options</:trigger>
                <.dropdown_menu_item>Calendly</.dropdown_menu_item>
                <.dropdown_menu_item>Slack</.dropdown_menu_item>
                <.dropdown_menu_separator />
                <.dropdown_menu_item>Webhook</.dropdown_menu_item>
              </.dropdown_menu_sub>
              <.dropdown_menu_separator />
              <.dropdown_menu_item>Advanced...</.dropdown_menu_item>
            </.dropdown_menu_sub>
            <.dropdown_menu_item>
              New Team
              <.dropdown_menu_shortcut>⌘+T</.dropdown_menu_shortcut>
            </.dropdown_menu_item>
          </.dropdown_menu_group>
          """
        ]
      },
      %VariationGroup{
        id: :sides,
        description: "Side: which edge of the trigger the menu opens from",
        template: """
        <div class="flex min-h-[420px] items-center justify-around gap-6 p-16">
          <.psb-variation-group/>
        </div>
        """,
        variations:
          for s <- ~w(top right bottom left) do
            %Variation{
              id: String.to_atom(s),
              attributes: %{id: "dm-side-#{s}", side: s},
              slots:
                [
                  ~s(<:trigger><.button variant="outline">#{String.capitalize(s)}</.button></:trigger>)
                ] ++ @sample_items
            }
          end
      },
      %VariationGroup{
        id: :alignments,
        description: "Align: how the menu lines up along the trigger's edge",
        template: """
        <div class="flex min-h-[320px] items-start justify-around p-12">
          <.psb-variation-group/>
        </div>
        """,
        variations:
          for a <- ~w(start center end) do
            %Variation{
              id: String.to_atom(a),
              attributes: %{id: "dm-align-#{a}", align: a},
              slots:
                [
                  ~s(<:trigger><.button variant="outline">Align #{a}</.button></:trigger>)
                ] ++ @sample_items
            }
          end
      },
      %Variation{
        id: :disabled_items,
        description: "Disabled items are skipped by keyboard nav",
        attributes: %{id: "dm-disabled"},
        slots: [
          ~s(<:trigger><.button variant="outline">Actions</.button></:trigger>),
          ~s(<.dropdown_menu_item>Edit</.dropdown_menu_item>),
          ~s|<.dropdown_menu_item disabled>Duplicate (disabled)</.dropdown_menu_item>|,
          ~s(<.dropdown_menu_item>Archive</.dropdown_menu_item>),
          ~s(<.dropdown_menu_separator />),
          ~s(<.dropdown_menu_item variant="destructive">Delete</.dropdown_menu_item>)
        ]
      }
    ]
  end
end
