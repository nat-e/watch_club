defmodule Shadcn.Storybook.Combobox do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Combobox

  def function, do: &Combobox.combobox/1

  def imports,
    do: [
      {Shadcn.Components.Combobox,
       [
         combobox_chips: 1,
         combobox_clear: 1,
         combobox_content: 1,
         combobox_empty: 1,
         combobox_group: 1,
         combobox_input: 1,
         combobox_item: 1,
         combobox_label: 1,
         combobox_list: 1,
         combobox_separator: 1,
         combobox_trigger: 1,
         combobox_value: 1
       ]},
      {Shadcn.Components.InputGroup, [input_group_addon: 1]}
    ]

  defp container_template(content) do
    """
    <div class="flex min-h-[360px] items-start justify-center p-12">
      <div class="w-[280px]">#{content}</div>
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  @frameworks [
    {"next.js", "Next.js"},
    {"sveltekit", "SvelteKit"},
    {"nuxt.js", "Nuxt.js"},
    {"remix", "Remix"},
    {"astro", "Astro"}
  ]

  @timezones [
    {"Americas",
     [
       "(GMT-5) New York",
       "(GMT-8) Los Angeles",
       "(GMT-6) Chicago",
       "(GMT-5) Toronto",
       "(GMT-8) Vancouver",
       "(GMT-3) São Paulo"
     ]},
    {"Europe",
     [
       "(GMT+0) London",
       "(GMT+1) Paris",
       "(GMT+1) Berlin",
       "(GMT+1) Rome",
       "(GMT+1) Madrid",
       "(GMT+1) Amsterdam"
     ]},
    {"Asia/Pacific",
     [
       "(GMT+9) Tokyo",
       "(GMT+8) Shanghai",
       "(GMT+8) Singapore",
       "(GMT+4) Dubai",
       "(GMT+11) Sydney",
       "(GMT+9) Seoul"
     ]}
  ]

  @countries [
    {"ar", "Argentina", "South America"},
    {"au", "Australia", "Oceania"},
    {"br", "Brazil", "South America"},
    {"ca", "Canada", "North America"},
    {"cn", "China", "Asia"},
    {"co", "Colombia", "South America"},
    {"eg", "Egypt", "Africa"},
    {"fr", "France", "Europe"},
    {"de", "Germany", "Europe"},
    {"it", "Italy", "Europe"},
    {"jp", "Japan", "Asia"},
    {"ke", "Kenya", "Africa"},
    {"mx", "Mexico", "North America"},
    {"nz", "New Zealand", "Oceania"},
    {"ng", "Nigeria", "Africa"},
    {"za", "South Africa", "Africa"},
    {"kr", "South Korea", "Asia"},
    {"gb", "United Kingdom", "Europe"},
    {"us", "United States", "North America"}
  ]

  defp framework_items do
    Enum.map(@frameworks, fn {v, label} ->
      ~s|<.combobox_item value="#{v}">#{label}</.combobox_item>|
    end)
  end

  defp timezone_groups(opts \\ []) do
    last = length(@timezones) - 1
    separators? = Keyword.get(opts, :separators, false)

    @timezones
    |> Enum.with_index()
    |> Enum.flat_map(fn {{label, zones}, idx} ->
      items =
        Enum.map(zones, fn z ->
          ~s|<.combobox_item value="#{z}">#{z}</.combobox_item>|
        end)

      group =
        ["<.combobox_group>"] ++
          [~s|<.combobox_label>#{label}</.combobox_label>|] ++
          items ++
          ["</.combobox_group>"]

      sep = if separators? and idx < last, do: ["<.combobox_separator />"], else: []
      group ++ sep
    end)
  end

  defp country_items do
    Enum.map(@countries, fn {code, label, continent} ->
      """
      <.combobox_item value="#{code}" label="#{label}">
        <span class="flex flex-col">
          <span class="font-medium">#{label}</span>
          <span class="text-xs text-muted-foreground">#{continent} (#{code})</span>
        </span>
      </.combobox_item>
      """
    end)
  end

  def variations do
    [
      %Variation{
        id: :basic,
        description: "Basic — single-select with type-to-filter",
        attributes: %{id: "cb-basic", name: "framework"},
        slots:
          [
            ~s|<.combobox_input placeholder="Select a framework" />|,
            "<.combobox_content>",
            ~s|<.combobox_empty>No items found.</.combobox_empty>|,
            "<.combobox_list>"
          ] ++
            framework_items() ++
            [
              "</.combobox_list>",
              "</.combobox_content>"
            ]
      },
      %Variation{
        id: :multiple,
        description: "Multi-select with chips and auto-highlight",
        attributes: %{
          id: "cb-multiple",
          name: "frameworks",
          multiple: true,
          auto_highlight: true,
          value: ["next.js"]
        },
        slots:
          [
            ~s|<.combobox_chips placeholder="Select frameworks" />|,
            "<.combobox_content>",
            ~s|<.combobox_empty>No items found.</.combobox_empty>|,
            "<.combobox_list>"
          ] ++
            framework_items() ++
            [
              "</.combobox_list>",
              "</.combobox_content>"
            ]
      },
      %Variation{
        id: :clear,
        description: "Clear button replaces the chevron when a value is selected",
        attributes: %{id: "cb-clear", name: "framework", value: "next.js"},
        slots:
          [
            ~s|<.combobox_input placeholder="Select a framework" show_clear />|,
            "<.combobox_content>",
            ~s|<.combobox_empty>No items found.</.combobox_empty>|,
            "<.combobox_list>"
          ] ++
            framework_items() ++
            [
              "</.combobox_list>",
              "</.combobox_content>"
            ]
      },
      %Variation{
        id: :groups,
        description: "Grouped items with labels and separators",
        attributes: %{id: "cb-groups", name: "timezone"},
        slots:
          [
            ~s|<.combobox_input placeholder="Select a timezone" />|,
            "<.combobox_content>",
            ~s|<.combobox_empty>No timezones found.</.combobox_empty>|,
            "<.combobox_list>"
          ] ++
            timezone_groups(separators: true) ++
            [
              "</.combobox_list>",
              "</.combobox_content>"
            ]
      },
      %Variation{
        id: :custom_items,
        description: "Items with custom label + description content",
        attributes: %{id: "cb-custom", name: "country"},
        slots:
          [
            ~s|<.combobox_input placeholder="Search countries..." />|,
            "<.combobox_content>",
            ~s|<.combobox_empty>No countries found.</.combobox_empty>|,
            "<.combobox_list>"
          ] ++
            country_items() ++
            [
              "</.combobox_list>",
              "</.combobox_content>"
            ]
      },
      %Variation{
        id: :invalid,
        description: "Error state — `aria-invalid` ring on the input",
        attributes: %{id: "cb-invalid", name: "framework", errors: ["Pick one."]},
        slots:
          [
            ~s|<.combobox_input placeholder="Select a framework" aria-invalid="true" />|,
            "<.combobox_content>",
            ~s|<.combobox_empty>No items found.</.combobox_empty>|,
            "<.combobox_list>"
          ] ++
            framework_items() ++
            [
              "</.combobox_list>",
              "</.combobox_content>"
            ]
      },
      %Variation{
        id: :disabled,
        description: "Whole combobox disabled — no interaction",
        attributes: %{id: "cb-disabled", name: "framework", disabled: true},
        slots:
          [
            ~s|<.combobox_input placeholder="Select a framework" disabled />|,
            "<.combobox_content>",
            ~s|<.combobox_empty>No items found.</.combobox_empty>|,
            "<.combobox_list>"
          ] ++
            framework_items() ++
            [
              "</.combobox_list>",
              "</.combobox_content>"
            ]
      },
      %Variation{
        id: :auto_highlight,
        description: "Auto-highlights the first match as you type",
        attributes: %{id: "cb-auto", name: "framework", auto_highlight: true},
        slots:
          [
            ~s|<.combobox_input placeholder="Select a framework" />|,
            "<.combobox_content>",
            ~s|<.combobox_empty>No items found.</.combobox_empty>|,
            "<.combobox_list>"
          ] ++
            framework_items() ++
            [
              "</.combobox_list>",
              "</.combobox_content>"
            ]
      },
      %Variation{
        id: :popup,
        description: "Custom button trigger; the search input lives inside the popup",
        attributes: %{id: "cb-popup", name: "country"},
        slots:
          [
            """
            <.combobox_trigger>
              <.combobox_value placeholder="Select country" />
            </.combobox_trigger>
            <.combobox_content>
              <.combobox_input placeholder="Search" show_trigger={false} />
              <.combobox_empty>No items found.</.combobox_empty>
              <.combobox_list>
            """
          ] ++
            country_items() ++
            [
              """
              </.combobox_list>
              </.combobox_content>
              """
            ]
      },
      %Variation{
        id: :input_group,
        description: "Leading addon icon inside the input group",
        attributes: %{id: "cb-igroup", name: "timezone"},
        slots:
          [
            """
            <.combobox_input placeholder="Select a timezone">
              <.input_group_addon>
                <Lucideicons.globe />
              </.input_group_addon>
            </.combobox_input>
            <.combobox_content>
              <.combobox_empty>No timezones found.</.combobox_empty>
              <.combobox_list>
            """
          ] ++
            timezone_groups() ++
            [
              """
              </.combobox_list>
              </.combobox_content>
              """
            ]
      }
    ]
  end
end
