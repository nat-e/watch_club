defmodule Shadcn.Storybook.ButtonGroup do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.ButtonGroup

  def function, do: &ButtonGroup.button_group/1

  def imports,
    do: [
      {Shadcn.Components.Button, [button: 1]},
      {Shadcn.Components.ButtonGroup, [button_group_separator: 1, button_group_text: 1]},
      {Shadcn.Components.Input, [input: 1]},
      {Shadcn.Components.InputGroup,
       [input_group: 1, input_group_addon: 1, input_group_input: 1]},
      {Shadcn.Components.DropdownMenu,
       [dropdown_menu: 1, dropdown_menu_item: 1, dropdown_menu_separator: 1]},
      {Shadcn.Components.Select, [select: 1, select_item: 1]},
      {Shadcn.Components.Popover, [popover: 1]},
      {Lucideicons,
       [
         arrow_right: 1,
         audio_lines: 1,
         chevron_down: 1,
         chevron_left: 1,
         chevron_right: 1,
         copy: 1,
         minus: 1,
         more_horizontal: 1,
         plus: 1,
         search: 1,
         settings_2: 1
       ]}
    ]

  def variations do
    [
      %Variation{
        id: :default,
        slots: [
          ~s|<.button variant="outline">Left</.button>|,
          ~s|<.button variant="outline">Center</.button>|,
          ~s|<.button variant="outline">Right</.button>|
        ]
      },
      %Variation{
        id: :orientation,
        description: "Vertical orientation",
        attributes: %{orientation: "vertical", "aria-label": "Media controls"},
        slots: [
          ~s|<.button variant="outline" size="icon" aria-label="Increase"><Lucideicons.plus /></.button>|,
          ~s|<.button variant="outline" size="icon" aria-label="Decrease"><Lucideicons.minus /></.button>|
        ]
      },
      %VariationGroup{
        id: :size,
        description: "Size — sm / default / lg via the button's size attr",
        template: """
        <div class="flex flex-col items-start gap-8">
          <.psb-variation-group/>
        </div>
        """,
        variations: [
          %Variation{
            id: :sm,
            slots: [
              ~s|<.button variant="outline" size="sm">Small</.button>|,
              ~s|<.button variant="outline" size="sm">Button</.button>|,
              ~s|<.button variant="outline" size="sm">Group</.button>|,
              ~s|<.button variant="outline" size="icon-sm" aria-label="Add"><Lucideicons.plus /></.button>|
            ]
          },
          %Variation{
            id: :default,
            slots: [
              ~s|<.button variant="outline">Default</.button>|,
              ~s|<.button variant="outline">Button</.button>|,
              ~s|<.button variant="outline">Group</.button>|,
              ~s|<.button variant="outline" size="icon" aria-label="Add"><Lucideicons.plus /></.button>|
            ]
          },
          %Variation{
            id: :lg,
            slots: [
              ~s|<.button variant="outline" size="lg">Large</.button>|,
              ~s|<.button variant="outline" size="lg">Button</.button>|,
              ~s|<.button variant="outline" size="lg">Group</.button>|,
              ~s|<.button variant="outline" size="icon-lg" aria-label="Add"><Lucideicons.plus /></.button>|
            ]
          }
        ]
      },
      %Variation{
        id: :nested,
        description: "Nested groups — gap between inner groups, joined within each",
        slots: [
          """
          <Shadcn.Components.ButtonGroup.button_group>
            <.button variant="outline" size="icon" aria-label="Back"><Lucideicons.chevron_left /></.button>
          </Shadcn.Components.ButtonGroup.button_group>
          """,
          """
          <Shadcn.Components.ButtonGroup.button_group>
            <.button variant="outline">Archive</.button>
            <.button variant="outline">Report</.button>
          </Shadcn.Components.ButtonGroup.button_group>
          """,
          """
          <Shadcn.Components.ButtonGroup.button_group>
            <.button variant="outline">Snooze</.button>
            <.button variant="outline" size="icon" aria-label="More"><Lucideicons.more_horizontal /></.button>
          </Shadcn.Components.ButtonGroup.button_group>
          """
        ]
      },
      %Variation{
        id: :separator,
        description: "Separator divides buttons within the same group",
        slots: [
          ~s|<.button variant="secondary" size="sm">Copy</.button>|,
          ~s|<.button_group_separator />|,
          ~s|<.button variant="secondary" size="sm">Paste</.button>|
        ]
      },
      %Variation{
        id: :split,
        description: "Split button — primary action + adjacent icon",
        slots: [
          ~s|<.button variant="secondary">Button</.button>|,
          ~s|<.button_group_separator />|,
          ~s|<.button variant="secondary" size="icon" aria-label="Add"><Lucideicons.plus /></.button>|
        ]
      },
      %Variation{
        id: :icon_only,
        description: "Icon-only nav",
        slots: [
          ~s|<.button variant="outline" size="icon" aria-label="Previous"><Lucideicons.chevron_left /></.button>|,
          ~s|<.button variant="outline" size="icon" aria-label="Copy"><Lucideicons.copy /></.button>|,
          ~s|<.button variant="outline" size="icon" aria-label="Next"><Lucideicons.chevron_right /></.button>|
        ]
      },
      %Variation{
        id: :with_input,
        description: "Input joined with a button",
        slots: [
          ~s|<.input placeholder="Search..." />|,
          ~s|<.button variant="outline" aria-label="Search"><Lucideicons.search /></.button>|
        ]
      },
      %Variation{
        id: :with_input_group,
        description: "Nested input group — pill-shaped composer",
        attributes: %{class: "[--radius:9999rem]"},
        slots: [
          """
          <Shadcn.Components.ButtonGroup.button_group>
            <.button variant="outline" size="icon" aria-label="Add"><Lucideicons.plus /></.button>
          </Shadcn.Components.ButtonGroup.button_group>
          """,
          """
          <Shadcn.Components.ButtonGroup.button_group>
            <.input_group>
              <.input_group_input placeholder="Send a message..." />
              <.input_group_addon align="inline-end">
                <Lucideicons.audio_lines />
              </.input_group_addon>
            </.input_group>
          </Shadcn.Components.ButtonGroup.button_group>
          """
        ]
      },
      %Variation{
        id: :with_dropdown,
        description: "Split button with dropdown menu",
        slots: [
          ~s|<.button variant="outline">Follow</.button>|,
          """
          <.dropdown_menu id="bg-dropdown" align="end">
            <:trigger>
              <.button variant="outline" size="icon" aria-label="More options">
                <Lucideicons.chevron_down />
              </.button>
            </:trigger>
            <.dropdown_menu_item>Mute conversation</.dropdown_menu_item>
            <.dropdown_menu_item>Mark as read</.dropdown_menu_item>
            <.dropdown_menu_item>Share conversation</.dropdown_menu_item>
            <.dropdown_menu_separator />
            <.dropdown_menu_item variant="destructive">Delete conversation</.dropdown_menu_item>
          </.dropdown_menu>
          """
        ]
      },
      %Variation{
        id: :with_select,
        description: "Select + input + send button — currency amount entry",
        slots: [
          """
          <Shadcn.Components.ButtonGroup.button_group>
            <.select id="bg-currency" value="$">
              <.select_item value="$">US Dollar</.select_item>
              <.select_item value="€">Euro</.select_item>
              <.select_item value="£">British Pound</.select_item>
            </.select>
            <.input placeholder="10.00" />
          </Shadcn.Components.ButtonGroup.button_group>
          """,
          """
          <Shadcn.Components.ButtonGroup.button_group>
            <.button variant="outline" size="icon" aria-label="Send"><Lucideicons.arrow_right /></.button>
          </Shadcn.Components.ButtonGroup.button_group>
          """
        ]
      },
      %Variation{
        id: :with_popover,
        description: "Button group with a popover trigger",
        slots: [
          ~s|<.button variant="outline">Edit</.button>|,
          ~s|<.button variant="outline">Duplicate</.button>|,
          """
          <.popover id="bg-popover" align="end">
            <:trigger>
              <.button variant="outline" size="icon" aria-label="Settings">
                <Lucideicons.settings_2 />
              </.button>
            </:trigger>
            <:title>Display options</:title>
            <:description>Customize what shows up in this view.</:description>
          </.popover>
          """
        ]
      }
    ]
  end
end
