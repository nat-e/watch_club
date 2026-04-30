defmodule Shadcn.Storybook.InputGroup do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.InputGroup

  def function, do: &InputGroup.input_group/1

  def imports,
    do: [
      {Shadcn.Components.DropdownMenu,
       [dropdown_menu: 1, dropdown_menu_group: 1, dropdown_menu_item: 1]},
      {Shadcn.Components.Field, [field: 1, field_description: 1, field_group: 1, field_label: 1]},
      {Shadcn.Components.InputGroup,
       [
         input_group_addon: 1,
         input_group_button: 1,
         input_group_input: 1,
         input_group_text: 1,
         input_group_textarea: 1
       ]},
      {Shadcn.Components.Kbd, [kbd: 1]},
      {Shadcn.Components.Spinner, [spinner: 1]},
      {Lucideicons,
       [
         check: 1,
         chevron_down: 1,
         copy: 1,
         corner_down_left: 1,
         credit_card: 1,
         eye_off: 1,
         file_code: 1,
         info: 1,
         loader: 1,
         mail: 1,
         more_horizontal: 1,
         refresh_cw: 1,
         search: 1,
         star: 1
       ]}
    ]

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
        id: :inline_start,
        description: "Addon at inline-start (leading)",
        template: """
        <.field class="max-w-sm">
          <.field_label for="ig-inline-start">Input</.field_label>
          <.input_group>
            <.input_group_input id="ig-inline-start" placeholder="Search..." />
            <.input_group_addon align="inline-start">
              <Lucideicons.search class="text-muted-foreground" />
            </.input_group_addon>
          </.input_group>
          <.field_description>Icon positioned at the start.</.field_description>
        </.field>
        """
      },
      %Variation{
        id: :inline_end,
        description: "Addon at inline-end (trailing)",
        template: """
        <.field class="max-w-sm">
          <.field_label for="ig-inline-end">Input</.field_label>
          <.input_group>
            <.input_group_input id="ig-inline-end" type="password" placeholder="Enter password" />
            <.input_group_addon align="inline-end">
              <Lucideicons.eye_off />
            </.input_group_addon>
          </.input_group>
          <.field_description>Icon positioned at the end.</.field_description>
        </.field>
        """
      },
      %Variation{
        id: :block_start,
        description: "Addon stacked above input/textarea",
        template: """
        <.field_group class="max-w-sm">
          <.field>
            <.field_label for="ig-bs-input">Input</.field_label>
            <.input_group class="h-auto">
              <.input_group_input id="ig-bs-input" placeholder="Enter your name" />
              <.input_group_addon align="block-start">
                <.input_group_text>Full Name</.input_group_text>
              </.input_group_addon>
            </.input_group>
            <.field_description>Header positioned above the input.</.field_description>
          </.field>
          <.field>
            <.field_label for="ig-bs-textarea">Textarea</.field_label>
            <.input_group>
              <.input_group_textarea id="ig-bs-textarea" placeholder="console.log('Hello, world!');" class="font-mono text-sm" />
              <.input_group_addon align="block-start">
                <Lucideicons.file_code class="text-muted-foreground" />
                <.input_group_text class="font-mono">script.js</.input_group_text>
                <.input_group_button size="icon-xs" class="ml-auto">
                  <Lucideicons.copy />
                  <span class="sr-only">Copy</span>
                </.input_group_button>
              </.input_group_addon>
            </.input_group>
            <.field_description>Header positioned above the textarea.</.field_description>
          </.field>
        </.field_group>
        """
      },
      %Variation{
        id: :block_end,
        description: "Addon stacked below input/textarea",
        template: """
        <.field_group class="max-w-sm">
          <.field>
            <.field_label for="ig-be-input">Input</.field_label>
            <.input_group class="h-auto">
              <.input_group_input id="ig-be-input" placeholder="Enter amount" />
              <.input_group_addon align="block-end">
                <.input_group_text>USD</.input_group_text>
              </.input_group_addon>
            </.input_group>
            <.field_description>Footer positioned below the input.</.field_description>
          </.field>
          <.field>
            <.field_label for="ig-be-textarea">Textarea</.field_label>
            <.input_group>
              <.input_group_textarea id="ig-be-textarea" placeholder="Write a comment..." />
              <.input_group_addon align="block-end">
                <.input_group_text>0/280</.input_group_text>
                <.input_group_button variant="default" size="sm" class="ml-auto">Post</.input_group_button>
              </.input_group_addon>
            </.input_group>
            <.field_description>Footer positioned below the textarea.</.field_description>
          </.field>
        </.field_group>
        """
      },
      %Variation{
        id: :icon,
        description: "Various icon-only addons",
        template: """
        <div class="grid w-full max-w-sm gap-6">
          <.input_group>
            <.input_group_input placeholder="Search..." />
            <.input_group_addon><Lucideicons.search /></.input_group_addon>
          </.input_group>
          <.input_group>
            <.input_group_input type="email" placeholder="Enter your email" />
            <.input_group_addon><Lucideicons.mail /></.input_group_addon>
          </.input_group>
          <.input_group>
            <.input_group_input placeholder="Card number" />
            <.input_group_addon><Lucideicons.credit_card /></.input_group_addon>
            <.input_group_addon align="inline-end"><Lucideicons.check /></.input_group_addon>
          </.input_group>
          <.input_group>
            <.input_group_input placeholder="Card number" />
            <.input_group_addon align="inline-end">
              <Lucideicons.star />
              <Lucideicons.info />
            </.input_group_addon>
          </.input_group>
        </div>
        """
      },
      %Variation{
        id: :text,
        description: "Text addons (currency, URL, suffix)",
        template: """
        <div class="grid w-full max-w-sm gap-6">
          <.input_group>
            <.input_group_addon>
              <.input_group_text>$</.input_group_text>
            </.input_group_addon>
            <.input_group_input placeholder="0.00" />
            <.input_group_addon align="inline-end">
              <.input_group_text>USD</.input_group_text>
            </.input_group_addon>
          </.input_group>
          <.input_group>
            <.input_group_addon>
              <.input_group_text>https://</.input_group_text>
            </.input_group_addon>
            <.input_group_input placeholder="example.com" class="pl-0.5!" />
            <.input_group_addon align="inline-end">
              <.input_group_text>.com</.input_group_text>
            </.input_group_addon>
          </.input_group>
          <.input_group>
            <.input_group_input placeholder="Enter your username" />
            <.input_group_addon align="inline-end">
              <.input_group_text>@company.com</.input_group_text>
            </.input_group_addon>
          </.input_group>
          <.input_group>
            <.input_group_textarea placeholder="Enter your message" />
            <.input_group_addon align="block-end">
              <.input_group_text class="text-xs text-muted-foreground">120 characters left</.input_group_text>
            </.input_group_addon>
          </.input_group>
        </div>
        """
      },
      %Variation{
        id: :button,
        description: "Button addons (copy, info popover, search)",
        template: """
        <div class="grid w-full max-w-sm gap-6">
          <.input_group>
            <.input_group_input placeholder="https://x.com/shadcn" readonly value="https://x.com/shadcn" />
            <.input_group_addon align="inline-end">
              <.input_group_button aria-label="Copy" title="Copy" size="icon-xs">
                <Lucideicons.copy />
              </.input_group_button>
            </.input_group_addon>
          </.input_group>
          <.input_group class="[--radius:9999px]">
            <.input_group_addon>
              <.input_group_button variant="secondary" size="icon-xs">
                <Lucideicons.info />
              </.input_group_button>
            </.input_group_addon>
            <.input_group_addon class="pl-1.5 text-muted-foreground">https://</.input_group_addon>
            <.input_group_input id="ig-btn-secure" />
            <.input_group_addon align="inline-end">
              <.input_group_button size="icon-xs">
                <Lucideicons.star />
              </.input_group_button>
            </.input_group_addon>
          </.input_group>
          <.input_group>
            <.input_group_input placeholder="Type to search..." />
            <.input_group_addon align="inline-end">
              <.input_group_button variant="secondary">Search</.input_group_button>
            </.input_group_addon>
          </.input_group>
        </div>
        """
      },
      %Variation{
        id: :kbd,
        description: "Keyboard shortcut hint",
        template: """
        <.input_group class="max-w-sm">
          <.input_group_input placeholder="Search..." />
          <.input_group_addon>
            <Lucideicons.search class="text-muted-foreground" />
          </.input_group_addon>
          <.input_group_addon align="inline-end">
            <.kbd>⌘K</.kbd>
          </.input_group_addon>
        </.input_group>
        """
      },
      %Variation{
        id: :dropdown,
        description: "Trailing dropdown menu trigger",
        template: """
        <div class="grid w-full max-w-sm gap-4">
          <.input_group>
            <.input_group_input placeholder="Enter file name" />
            <.input_group_addon align="inline-end">
              <.dropdown_menu id="ig-dd-more" align="end">
                <:trigger>
                  <.input_group_button variant="ghost" aria-label="More" size="icon-xs">
                    <Lucideicons.more_horizontal />
                  </.input_group_button>
                </:trigger>
                <.dropdown_menu_group>
                  <.dropdown_menu_item>Settings</.dropdown_menu_item>
                  <.dropdown_menu_item>Copy path</.dropdown_menu_item>
                  <.dropdown_menu_item>Open location</.dropdown_menu_item>
                </.dropdown_menu_group>
              </.dropdown_menu>
            </.input_group_addon>
          </.input_group>
          <.input_group class="[--radius:1rem]">
            <.input_group_input placeholder="Enter search query" />
            <.input_group_addon align="inline-end">
              <.dropdown_menu id="ig-dd-search" align="end">
                <:trigger>
                  <.input_group_button variant="ghost" class="pr-1.5! text-xs">
                    Search In... <Lucideicons.chevron_down class="size-3" />
                  </.input_group_button>
                </:trigger>
                <.dropdown_menu_group>
                  <.dropdown_menu_item>Documentation</.dropdown_menu_item>
                  <.dropdown_menu_item>Blog Posts</.dropdown_menu_item>
                  <.dropdown_menu_item>Changelog</.dropdown_menu_item>
                </.dropdown_menu_group>
              </.dropdown_menu>
            </.input_group_addon>
          </.input_group>
        </div>
        """
      },
      %Variation{
        id: :spinner,
        description: "Loading state with spinner addon",
        template: """
        <div class="grid w-full max-w-sm gap-4">
          <.input_group>
            <.input_group_input placeholder="Searching..." />
            <.input_group_addon align="inline-end"><.spinner /></.input_group_addon>
          </.input_group>
          <.input_group>
            <.input_group_input placeholder="Processing..." />
            <.input_group_addon><.spinner /></.input_group_addon>
          </.input_group>
          <.input_group>
            <.input_group_input placeholder="Saving changes..." />
            <.input_group_addon align="inline-end">
              <.input_group_text>Saving...</.input_group_text>
              <.spinner />
            </.input_group_addon>
          </.input_group>
          <.input_group>
            <.input_group_input placeholder="Refreshing data..." />
            <.input_group_addon>
              <Lucideicons.loader class="animate-spin" />
            </.input_group_addon>
            <.input_group_addon align="inline-end">
              <.input_group_text class="text-muted-foreground">Please wait...</.input_group_text>
            </.input_group_addon>
          </.input_group>
        </div>
        """
      },
      %Variation{
        id: :textarea,
        description: "Code editor with header and footer",
        template: """
        <.input_group class="w-full max-w-md">
          <.input_group_textarea id="ig-ta-code" placeholder="console.log('Hello, world!');" class="min-h-[200px] font-mono text-sm" />
          <.input_group_addon align="block-start" class="border-b">
            <.input_group_text class="font-mono font-medium">
              <Lucideicons.file_code />
              script.js
            </.input_group_text>
            <.input_group_button class="ml-auto" size="icon-xs">
              <Lucideicons.refresh_cw />
            </.input_group_button>
            <.input_group_button variant="ghost" size="icon-xs">
              <Lucideicons.copy />
            </.input_group_button>
          </.input_group_addon>
          <.input_group_addon align="block-end" class="border-t">
            <.input_group_text>Line 1, Column 1</.input_group_text>
            <.input_group_button size="sm" class="ml-auto" variant="default">
              Run <Lucideicons.corner_down_left />
            </.input_group_button>
          </.input_group_addon>
        </.input_group>
        """
      }
    ]
  end
end
