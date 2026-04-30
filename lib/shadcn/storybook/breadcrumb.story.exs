defmodule Shadcn.Storybook.Breadcrumb do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Breadcrumb

  def function, do: &Breadcrumb.breadcrumb/1

  def imports,
    do: [
      {Shadcn.Components.Breadcrumb,
       [
         breadcrumb_ellipsis: 1,
         breadcrumb_item: 1,
         breadcrumb_link: 1,
         breadcrumb_page: 1,
         breadcrumb_separator: 1
       ]},
      {Shadcn.Components.DropdownMenu,
       [
         dropdown_menu: 1,
         dropdown_menu_item: 1
       ]},
      {Lucideicons, [slash: 1, chevron_down: 1, ellipsis: 1]}
    ]

  def variations do
    [
      %Variation{
        id: :default,
        description: "Basic — Home / Components / Breadcrumb",
        slots: [
          ~s|<.breadcrumb_item><.breadcrumb_link href="#">Home</.breadcrumb_link></.breadcrumb_item>|,
          ~s|<.breadcrumb_separator />|,
          ~s|<.breadcrumb_item><.breadcrumb_link href="#">Components</.breadcrumb_link></.breadcrumb_item>|,
          ~s|<.breadcrumb_separator />|,
          ~s|<.breadcrumb_item><.breadcrumb_page>Breadcrumb</.breadcrumb_page></.breadcrumb_item>|
        ]
      },
      %Variation{
        id: :custom_separator,
        description: "Custom separator (slash)",
        slots: [
          ~s|<.breadcrumb_item><.breadcrumb_link href="#">Home</.breadcrumb_link></.breadcrumb_item>|,
          ~s|<.breadcrumb_separator><Lucideicons.slash /></.breadcrumb_separator>|,
          ~s|<.breadcrumb_item><.breadcrumb_link href="#">Components</.breadcrumb_link></.breadcrumb_item>|,
          ~s|<.breadcrumb_separator><Lucideicons.slash /></.breadcrumb_separator>|,
          ~s|<.breadcrumb_item><.breadcrumb_page>Breadcrumb</.breadcrumb_page></.breadcrumb_item>|
        ]
      },
      %Variation{
        id: :with_dropdown,
        description: "Dropdown — text trigger inside an item",
        slots: [
          ~s|<.breadcrumb_item><.breadcrumb_link href="#">Home</.breadcrumb_link></.breadcrumb_item>|,
          ~s|<.breadcrumb_separator/>|,
          """
          <.breadcrumb_item>
            <.dropdown_menu id="bc-dropdown" align="start">
              <:trigger>
                <button class="flex items-center gap-1">
                  Components
                  <Lucideicons.chevron_down class="size-3.5" />
                </button>
              </:trigger>
              <.dropdown_menu_item>Documentation</.dropdown_menu_item>
              <.dropdown_menu_item>Themes</.dropdown_menu_item>
              <.dropdown_menu_item>GitHub</.dropdown_menu_item>
            </.dropdown_menu>
          </.breadcrumb_item>
          """,
          ~s|<.breadcrumb_separator/>|,
          ~s|<.breadcrumb_item><.breadcrumb_page>Breadcrumb</.breadcrumb_page></.breadcrumb_item>|
        ]
      },
      %Variation{
        id: :with_dropdown_ellipsis,
        description: "Dropdown — ellipsis trigger collapsing middle items",
        slots: [
          ~s|<.breadcrumb_item><.breadcrumb_link href="#">Home</.breadcrumb_link></.breadcrumb_item>|,
          ~s|<.breadcrumb_separator />|,
          """
          <.breadcrumb_item>
            <.dropdown_menu id="bc-dropdown-ellipsis" align="start">
              <:trigger>
                <button type="button" class="flex items-center gap-1" aria-label="Toggle menu">
                  <Lucideicons.ellipsis class="size-4" />
                  <span class="sr-only">Toggle menu</span>
                </button>
              </:trigger>
              <.dropdown_menu_item>Documentation</.dropdown_menu_item>
              <.dropdown_menu_item>Themes</.dropdown_menu_item>
              <.dropdown_menu_item>GitHub</.dropdown_menu_item>
            </.dropdown_menu>
          </.breadcrumb_item>
          """,
          ~s|<.breadcrumb_separator />|,
          ~s|<.breadcrumb_item><.breadcrumb_link href="#">Components</.breadcrumb_link></.breadcrumb_item>|,
          ~s|<.breadcrumb_separator />|,
          ~s|<.breadcrumb_item><.breadcrumb_page>Breadcrumb</.breadcrumb_page></.breadcrumb_item>|
        ]
      },
      %Variation{
        id: :collapsed,
        description: "Collapsed — static ellipsis (no dropdown)",
        slots: [
          ~s|<.breadcrumb_item><.breadcrumb_link href="#">Home</.breadcrumb_link></.breadcrumb_item>|,
          ~s|<.breadcrumb_separator />|,
          ~s|<.breadcrumb_item><.breadcrumb_ellipsis /></.breadcrumb_item>|,
          ~s|<.breadcrumb_separator />|,
          ~s|<.breadcrumb_item><.breadcrumb_link href="#">Components</.breadcrumb_link></.breadcrumb_item>|,
          ~s|<.breadcrumb_separator />|,
          ~s|<.breadcrumb_item><.breadcrumb_page>Breadcrumb</.breadcrumb_page></.breadcrumb_item>|
        ]
      }
    ]
  end
end
