defmodule Shadcn.Storybook.NavigationMenu do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.NavigationMenu

  def function, do: &NavigationMenu.navigation_menu/1

  def imports,
    do: [
      {Shadcn.Components.NavigationMenu, [navigation_menu_item: 1, navigation_menu_link: 1]},
      {Lucideicons, [circle: 1, circle_check: 1, circle_help: 1]}
    ]

  defp container_template(content) do
    """
    <div class="flex min-h-[420px] items-start justify-center p-12">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :default,
        description: "Mega-menu with viewport (Home, Components) + trigger-style link.",
        slots: [
          """
          <.navigation_menu_item>
            <:trigger>Home</:trigger>
            <ul class="grid gap-2 md:w-[400px] lg:w-[500px] lg:grid-cols-[.75fr_1fr]">
              <li class="row-span-3">
                <.navigation_menu_link
                  href="#"
                  class="from-muted/50 to-muted flex h-full w-full flex-col justify-end rounded-md bg-linear-to-b p-4 no-underline outline-hidden transition-all duration-200 select-none focus:shadow-md md:p-6"
                >
                  <div class="mb-2 text-lg font-medium sm:mt-4">Watch Club</div>
                  <p class="text-muted-foreground text-sm leading-tight">
                    Beautifully designed components built with Tailwind CSS.
                  </p>
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Introduction</div>
                  <p class="line-clamp-2 text-muted-foreground text-sm leading-snug">
                    Re-usable components built using Tailwind CSS.
                  </p>
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Installation</div>
                  <p class="line-clamp-2 text-muted-foreground text-sm leading-snug">
                    How to install dependencies and structure your app.
                  </p>
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Typography</div>
                  <p class="line-clamp-2 text-muted-foreground text-sm leading-snug">
                    Styles for headings, paragraphs, lists...etc
                  </p>
                </.navigation_menu_link>
              </li>
            </ul>
          </.navigation_menu_item>
          """,
          """
          <.navigation_menu_item>
            <:trigger>Components</:trigger>
            <ul class="grid gap-2 sm:w-[400px] md:w-[500px] md:grid-cols-2 lg:w-[600px]">
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Alert Dialog</div>
                  <p class="line-clamp-2 text-muted-foreground text-sm leading-snug">
                    A modal dialog that interrupts the user with important content and expects a response.
                  </p>
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Hover Card</div>
                  <p class="line-clamp-2 text-muted-foreground text-sm leading-snug">
                    For sighted users to preview content available behind a link.
                  </p>
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Progress</div>
                  <p class="line-clamp-2 text-muted-foreground text-sm leading-snug">
                    Displays an indicator showing the completion progress of a task.
                  </p>
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Scroll-area</div>
                  <p class="line-clamp-2 text-muted-foreground text-sm leading-snug">
                    Visually or semantically separates content.
                  </p>
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Tabs</div>
                  <p class="line-clamp-2 text-muted-foreground text-sm leading-snug">
                    Layered sections of content displayed one at a time.
                  </p>
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Tooltip</div>
                  <p class="line-clamp-2 text-muted-foreground text-sm leading-snug">
                    A popup with information about an element on focus or hover.
                  </p>
                </.navigation_menu_link>
              </li>
            </ul>
          </.navigation_menu_item>
          """
        ]
      },
      %Variation{
        id: :link,
        description: "A `navigation_menu_link` styled as a top-level trigger (no dropdown).",
        slots: [
          """
          <.navigation_menu_item>
            <.navigation_menu_link href="#" class="navigation-menu-trigger-style">
              Docs
            </.navigation_menu_link>
          </.navigation_menu_item>
          """
        ]
      },
      %Variation{
        id: :list,
        description: "A 300px-wide list of links with title + description.",
        slots: [
          """
          <.navigation_menu_item>
            <:trigger>List</:trigger>
            <ul class="grid w-[300px] gap-2">
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Components</div>
                  <p class="text-muted-foreground text-sm leading-snug">
                    Browse all components in the library.
                  </p>
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Documentation</div>
                  <p class="text-muted-foreground text-sm leading-snug">
                    Learn how to use the library.
                  </p>
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Blog</div>
                  <p class="text-muted-foreground text-sm leading-snug">
                    Read our latest blog posts.
                  </p>
                </.navigation_menu_link>
              </li>
            </ul>
          </.navigation_menu_item>
          """
        ]
      },
      %Variation{
        id: :simple,
        description: "A 200px-wide list of plain links (no description).",
        slots: [
          """
          <.navigation_menu_item>
            <:trigger>Simple</:trigger>
            <ul class="grid w-[200px] gap-2">
              <li><.navigation_menu_link href="#">Components</.navigation_menu_link></li>
              <li><.navigation_menu_link href="#">Documentation</.navigation_menu_link></li>
              <li><.navigation_menu_link href="#">Blocks</.navigation_menu_link></li>
            </ul>
          </.navigation_menu_item>
          """
        ]
      },
      %Variation{
        id: :with_icon,
        description: "Links with leading icons.",
        slots: [
          """
          <.navigation_menu_item>
            <:trigger>With Icon</:trigger>
            <ul class="grid w-[200px] gap-2">
              <li>
                <.navigation_menu_link href="#">
                  <Lucideicons.circle_help />Backlog
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#">
                  <Lucideicons.circle />To Do
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#">
                  <Lucideicons.circle_check />Done
                </.navigation_menu_link>
              </li>
            </ul>
          </.navigation_menu_item>
          """
        ]
      },
      %Variation{
        id: :no_viewport,
        description: "`viewport={false}`: each item drops its own panel inline.",
        attributes: %{viewport: false},
        slots: [
          """
          <.navigation_menu_item>
            <:trigger>Home</:trigger>
            <ul class="grid w-[300px] gap-2">
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Introduction</div>
                  <p class="text-muted-foreground text-sm leading-snug">
                    Re-usable components built using Tailwind CSS.
                  </p>
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#" class="flex-col items-start">
                  <div class="text-sm leading-none font-medium">Installation</div>
                  <p class="text-muted-foreground text-sm leading-snug">
                    How to install dependencies and structure your app.
                  </p>
                </.navigation_menu_link>
              </li>
            </ul>
          </.navigation_menu_item>
          """,
          """
          <.navigation_menu_item>
            <:trigger>Items</:trigger>
            <ul class="grid w-[200px] gap-2">
              <li>
                <.navigation_menu_link href="#">
                  <Lucideicons.circle_help />Backlog
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#">
                  <Lucideicons.circle />To Do
                </.navigation_menu_link>
              </li>
              <li>
                <.navigation_menu_link href="#">
                  <Lucideicons.circle_check />Done
                </.navigation_menu_link>
              </li>
            </ul>
          </.navigation_menu_item>
          """,
          """
          <.navigation_menu_item>
            <.navigation_menu_link href="#" class="navigation-menu-trigger-style">
              Docs
            </.navigation_menu_link>
          </.navigation_menu_item>
          """
        ]
      }
    ]
  end
end
