defmodule WatchClubWeb.Storybook.DropdownMenu do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.DropdownMenu

  def function, do: &DropdownMenu.dropdown_menu/1

  def imports do
    [
      {WatchClubWeb.Components.UI.Button, [button: 1]},
      {WatchClubWeb.Components.UI.DropdownMenu,
       [dropdown_menu_item: 1, dropdown_menu_separator: 1]},
      {Lucideicons, [ellipsis_vertical: 1, log_out: 1, settings: 1, trash_2: 1, user: 1]}
    ]
  end

  defp container_template(content) do
    """
    <div class="flex min-h-80 items-start justify-center p-12 text-text">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :default,
        description: "Simple action menu",
        attributes: %{id: "wc-dropdown-default"},
        slots: [
          ~s(<:trigger><.button variant="secondary">Open menu</.button></:trigger>),
          ~s(<.dropdown_menu_item><Lucideicons.user />Profile</.dropdown_menu_item>),
          ~s(<.dropdown_menu_item><Lucideicons.settings />Settings</.dropdown_menu_item>),
          ~s(<.dropdown_menu_separator />),
          ~s(<.dropdown_menu_item variant="destructive"><Lucideicons.log_out />Sign out</.dropdown_menu_item>)
        ]
      },
      %Variation{
        id: :icon_trigger,
        description: "Icon-only trigger used in tables and sidebars",
        attributes: %{id: "wc-dropdown-icon-trigger"},
        slots: [
          ~s(<:trigger><.button size="icon" variant="ghost" aria-label="Open menu"><Lucideicons.ellipsis_vertical /></.button></:trigger>),
          ~s(<.dropdown_menu_item><Lucideicons.user />Share invitation</.dropdown_menu_item>),
          ~s(<.dropdown_menu_item variant="destructive"><Lucideicons.trash_2 />Delete invitation</.dropdown_menu_item>)
        ]
      },
      %Variation{
        id: :disabled_item,
        description: "Disabled item",
        attributes: %{id: "wc-dropdown-disabled"},
        slots: [
          ~s(<:trigger><.button variant="secondary">Club actions</.button></:trigger>),
          ~s(<.dropdown_menu_item>Manage members</.dropdown_menu_item>),
          ~s(<.dropdown_menu_item disabled>Transfer ownership</.dropdown_menu_item>),
          ~s(<.dropdown_menu_separator />),
          ~s(<.dropdown_menu_item variant="destructive">Delete club</.dropdown_menu_item>)
        ]
      }
    ]
  end
end
