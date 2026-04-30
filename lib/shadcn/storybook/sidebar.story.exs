defmodule Shadcn.Storybook.Sidebar do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Sidebar

  def function, do: &Sidebar.sidebar_provider/1

  def imports,
    do: [
      {Shadcn.Components.Button, [button: 1]},
      {Shadcn.Components.Sidebar,
       [
         sidebar: 1,
         sidebar_group: 1,
         sidebar_input: 1,
         sidebar_inset: 1,
         sidebar_menu: 1,
         sidebar_menu_item: 1,
         sidebar_menu_skeleton: 1,
         sidebar_menu_sub_item: 1,
         sidebar_rail: 1,
         sidebar_separator: 1,
         sidebar_trigger: 1
       ]},
      {Lucideicons,
       [
         bot: 1,
         book_open: 1,
         calendar: 1,
         chevron_right: 1,
         command: 1,
         file_text: 1,
         frame: 1,
         gallery_horizontal_end: 1,
         home: 1,
         inbox: 1,
         life_buoy: 1,
         map: 1,
         more_horizontal: 1,
         pie_chart: 1,
         plus: 1,
         search: 1,
         send: 1,
         settings: 1,
         settings_2: 1,
         square_terminal: 1,
         trash_2: 1,
         user: 1
       ]}
    ]

  defp container_template(content) do
    """
    <div
      class="relative isolate h-[520px] w-full overflow-hidden rounded-md border"
      style="--sidebar-wrapper-min-h: 100%"
    >
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  defp default_inset(label) do
    """
    <.sidebar_inset>
      <header class="flex h-12 items-center gap-2 border-b px-4">
        <.sidebar_trigger />
        <span class="text-sm font-medium">#{label}</span>
      </header>
      <div class="flex flex-1 flex-col gap-4 p-4">
        <div class="aspect-video rounded-xl bg-muted/50"></div>
        <div class="grid grid-cols-2 gap-4">
          <div class="aspect-video rounded-xl bg-muted/30"></div>
          <div class="aspect-video rounded-xl bg-muted/30"></div>
        </div>
      </div>
    </.sidebar_inset>
    """
  end

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default — collapsible=offcanvas, side=left",
        attributes: %{id: "sb-default"},
        slots: [
          """
          <.sidebar>
            <:header>
              <.sidebar_menu>
                <.sidebar_menu_item size="lg">
                  <:icon><Lucideicons.gallery_horizontal_end /></:icon>
                  <span class="font-semibold">Watch Club</span>
                </.sidebar_menu_item>
              </.sidebar_menu>
            </:header>

            <.sidebar_group>
              <:label>Application</:label>
              <.sidebar_menu>
                <.sidebar_menu_item href="#" active>
                  <:icon><Lucideicons.home /></:icon>
                  Dashboard
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#">
                  <:icon><Lucideicons.search /></:icon>
                  Search
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#">
                  <:icon><Lucideicons.inbox /></:icon>
                  Inbox
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#">
                  <:icon><Lucideicons.calendar /></:icon>
                  Calendar
                </.sidebar_menu_item>
              </.sidebar_menu>
            </.sidebar_group>

            <:footer>
              <.sidebar_menu>
                <.sidebar_menu_item href="#">
                  <:icon><Lucideicons.user /></:icon>
                  Profile
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#">
                  <:icon><Lucideicons.settings /></:icon>
                  Settings
                </.sidebar_menu_item>
              </.sidebar_menu>
            </:footer>
          </.sidebar>
          """,
          default_inset("Dashboard")
        ]
      },
      %Variation{
        id: :collapsible_icon,
        description: ~s|collapsible="icon" — collapses to icon-only rail with tooltips|,
        attributes: %{id: "sb-icon"},
        slots: [
          """
          <.sidebar collapsible="icon">
            <:header>
              <.sidebar_menu>
                <.sidebar_menu_item size="lg" tooltip="Watch Club">
                  <:icon><Lucideicons.command /></:icon>
                  <span class="font-semibold">Watch Club</span>
                </.sidebar_menu_item>
              </.sidebar_menu>
            </:header>

            <.sidebar_group>
              <:label>Platform</:label>
              <.sidebar_menu>
                <.sidebar_menu_item href="#" tooltip="Playground" active>
                  <:icon><Lucideicons.square_terminal /></:icon>
                  Playground
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#" tooltip="Models">
                  <:icon><Lucideicons.frame /></:icon>
                  Models
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#" tooltip="Documentation">
                  <:icon><Lucideicons.book_open /></:icon>
                  Documentation
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#" tooltip="Settings">
                  <:icon><Lucideicons.settings_2 /></:icon>
                  Settings
                </.sidebar_menu_item>
              </.sidebar_menu>
            </.sidebar_group>

            <:footer>
              <.sidebar_menu>
                <.sidebar_menu_item href="#" tooltip="Support">
                  <:icon><Lucideicons.life_buoy /></:icon>
                  Support
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#" tooltip="Feedback">
                  <:icon><Lucideicons.send /></:icon>
                  Feedback
                </.sidebar_menu_item>
              </.sidebar_menu>
            </:footer>

            <.sidebar_rail />
          </.sidebar>
          """,
          default_inset("Playground")
        ]
      },
      %Variation{
        id: :collapsible_none,
        description: ~s|collapsible="none" — fixed, no toggle|,
        attributes: %{id: "sb-none"},
        slots: [
          """
          <.sidebar collapsible="none">
            <:header>
              <.sidebar_menu>
                <.sidebar_menu_item size="lg">
                  <:icon><Lucideicons.gallery_horizontal_end /></:icon>
                  <span class="font-semibold">Watch Club</span>
                </.sidebar_menu_item>
              </.sidebar_menu>
            </:header>

            <.sidebar_group>
              <:label>Browse</:label>
              <.sidebar_menu>
                <.sidebar_menu_item href="#" active>
                  <:icon><Lucideicons.home /></:icon>
                  Home
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#">
                  <:icon><Lucideicons.book_open /></:icon>
                  Library
                </.sidebar_menu_item>
              </.sidebar_menu>
            </.sidebar_group>
          </.sidebar>
          """,
          """
          <.sidebar_inset>
            <header class="flex h-12 items-center gap-2 border-b px-4">
              <span class="text-sm font-medium">Library</span>
            </header>
            <div class="p-4 text-sm text-muted-foreground">
              No trigger — this sidebar always stays open.
            </div>
          </.sidebar_inset>
          """
        ]
      },
      %Variation{
        id: :variant_floating,
        description: ~s|variant="floating" — rounded panel with a ring shadow|,
        attributes: %{id: "sb-floating"},
        slots: [
          """
          <.sidebar variant="floating" collapsible="icon">
            <:header>
              <.sidebar_menu>
                <.sidebar_menu_item size="lg" tooltip="Watch Club">
                  <:icon><Lucideicons.command /></:icon>
                  <span class="font-semibold">Watch Club</span>
                </.sidebar_menu_item>
              </.sidebar_menu>
            </:header>

            <.sidebar_group>
              <:label>Workspace</:label>
              <.sidebar_menu>
                <.sidebar_menu_item href="#" tooltip="Dashboard" active>
                  <:icon><Lucideicons.home /></:icon>
                  Dashboard
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#" tooltip="Reports">
                  <:icon><Lucideicons.pie_chart /></:icon>
                  Reports
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#" tooltip="Map">
                  <:icon><Lucideicons.map /></:icon>
                  Map
                </.sidebar_menu_item>
              </.sidebar_menu>
            </.sidebar_group>

            <.sidebar_rail />
          </.sidebar>
          """,
          default_inset("Dashboard")
        ]
      },
      %Variation{
        id: :variant_inset,
        description:
          ~s|variant="inset" — sidebar floats; content area is inset with rounded corners|,
        attributes: %{id: "sb-inset"},
        slots: [
          """
          <.sidebar variant="inset" collapsible="icon">
            <:header>
              <.sidebar_menu>
                <.sidebar_menu_item size="lg" tooltip="Acme Inc.">
                  <:icon><Lucideicons.gallery_horizontal_end /></:icon>
                  <span class="font-semibold">Acme Inc.</span>
                </.sidebar_menu_item>
              </.sidebar_menu>
            </:header>

            <.sidebar_group>
              <:label>Platform</:label>
              <.sidebar_menu>
                <.sidebar_menu_item href="#" tooltip="Dashboard" active>
                  <:icon><Lucideicons.home /></:icon>
                  Dashboard
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#" tooltip="Calendar">
                  <:icon><Lucideicons.calendar /></:icon>
                  Calendar
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#" tooltip="Inbox">
                  <:icon><Lucideicons.inbox /></:icon>
                  Inbox
                </.sidebar_menu_item>
              </.sidebar_menu>
            </.sidebar_group>

            <.sidebar_rail />
          </.sidebar>
          """,
          default_inset("Dashboard")
        ]
      },
      %Variation{
        id: :collapsible_groups,
        description:
          "Collapsible menu items — chevron rotates and reveals/hides the sub-menu on click",
        attributes: %{id: "sb-collapsible-groups"},
        slots: [
          """
          <.sidebar collapsible="icon">
            <:header>
              <.sidebar_menu>
                <.sidebar_menu_item size="lg" tooltip="Watch Club">
                  <:icon><Lucideicons.command /></:icon>
                  <span class="font-semibold">Watch Club</span>
                </.sidebar_menu_item>
              </.sidebar_menu>
            </:header>

            <.sidebar_group>
              <:label>Platform</:label>
              <.sidebar_menu>
                <.sidebar_menu_item collapsible default_open tooltip="Playground">
                  <:icon><Lucideicons.square_terminal /></:icon>
                  Playground
                  <:sub>
                    <.sidebar_menu_sub_item href="#">History</.sidebar_menu_sub_item>
                    <.sidebar_menu_sub_item href="#" active>Starred</.sidebar_menu_sub_item>
                    <.sidebar_menu_sub_item href="#">Settings</.sidebar_menu_sub_item>
                  </:sub>
                </.sidebar_menu_item>
                <.sidebar_menu_item collapsible tooltip="Models">
                  <:icon><Lucideicons.bot /></:icon>
                  Models
                  <:sub>
                    <.sidebar_menu_sub_item href="#">Genesis</.sidebar_menu_sub_item>
                    <.sidebar_menu_sub_item href="#">Explorer</.sidebar_menu_sub_item>
                    <.sidebar_menu_sub_item href="#">Quantum</.sidebar_menu_sub_item>
                  </:sub>
                </.sidebar_menu_item>
                <.sidebar_menu_item collapsible tooltip="Documentation">
                  <:icon><Lucideicons.book_open /></:icon>
                  Documentation
                  <:sub>
                    <.sidebar_menu_sub_item href="#">Introduction</.sidebar_menu_sub_item>
                    <.sidebar_menu_sub_item href="#">Get Started</.sidebar_menu_sub_item>
                    <.sidebar_menu_sub_item href="#">Tutorials</.sidebar_menu_sub_item>
                    <.sidebar_menu_sub_item href="#">Changelog</.sidebar_menu_sub_item>
                  </:sub>
                </.sidebar_menu_item>
              </.sidebar_menu>
            </.sidebar_group>

            <.sidebar_rail />
          </.sidebar>
          """,
          default_inset("Starred")
        ]
      },
      %Variation{
        id: :side_right,
        description: ~s|side="right" — mirrored layout|,
        attributes: %{id: "sb-right"},
        slots: [
          """
          <.sidebar side="right" collapsible="icon">
            <:header>
              <.sidebar_menu>
                <.sidebar_menu_item size="lg" tooltip="Watch Club">
                  <:icon><Lucideicons.command /></:icon>
                  <span class="font-semibold">Watch Club</span>
                </.sidebar_menu_item>
              </.sidebar_menu>
            </:header>

            <.sidebar_group>
              <:label>Filters</:label>
              <.sidebar_menu>
                <.sidebar_menu_item href="#" tooltip="All" active>
                  <:icon><Lucideicons.home /></:icon>
                  All items
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#" tooltip="Recent">
                  <:icon><Lucideicons.calendar /></:icon>
                  Recent
                </.sidebar_menu_item>
              </.sidebar_menu>
            </.sidebar_group>

            <.sidebar_rail />
          </.sidebar>
          """,
          default_inset("Library")
        ]
      },
      %Variation{
        id: :rich,
        description:
          "Rich — group action, menu badges, hover-only menu actions, sub-menu, skeleton, separator, search input",
        attributes: %{id: "sb-rich"},
        slots: [
          """
          <.sidebar collapsible="icon">
            <:header>
              <.sidebar_menu>
                <.sidebar_menu_item size="lg" tooltip="Watch Club">
                  <:icon><Lucideicons.command /></:icon>
                  <span class="font-semibold">Watch Club</span>
                </.sidebar_menu_item>
              </.sidebar_menu>
              <.sidebar_input placeholder="Search the docs..." />
            </:header>

            <.sidebar_group>
              <:label>Projects</:label>
              <:action aria-label="Add project"><.button variant="ghost" size="icon-xs"><Lucideicons.plus /></.button></:action>
              <.sidebar_menu>
                <.sidebar_menu_item href="#" tooltip="Design Engineering" active>
                  <:icon><Lucideicons.frame /></:icon>
                  Design Engineering
                  <:action show_on_hover aria-label="More">
                    <.button variant="ghost" size="icon-xs"><Lucideicons.more_horizontal /></.button>
                  </:action>
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#" tooltip="Sales & Marketing">
                  <:icon><Lucideicons.pie_chart /></:icon>
                  Sales & Marketing
                  <:badge>12</:badge>
                </.sidebar_menu_item>
                <.sidebar_menu_item href="#" tooltip="Travel">
                  <:icon><Lucideicons.map /></:icon>
                  Travel
                  <:action show_on_hover aria-label="Delete">
                    <.button variant="ghost" size="icon-xs"><Lucideicons.trash_2 /></.button>
                  </:action>
                </.sidebar_menu_item>
              </.sidebar_menu>
            </.sidebar_group>

            <.sidebar_separator />

            <.sidebar_group>
              <:label>Documents</:label>
              <.sidebar_menu>
                <.sidebar_menu_item tooltip="Getting Started">
                  <:icon><Lucideicons.book_open /></:icon>
                  Getting Started
                  <:sub>
                    <.sidebar_menu_sub_item href="#">Introduction</.sidebar_menu_sub_item>
                    <.sidebar_menu_sub_item href="#" active>Installation</.sidebar_menu_sub_item>
                    <.sidebar_menu_sub_item href="#">Project Structure</.sidebar_menu_sub_item>
                  </:sub>
                </.sidebar_menu_item>
                <.sidebar_menu_item tooltip="Building Your Application">
                  <:icon><Lucideicons.file_text /></:icon>
                  Building Your Application
                  <:sub>
                    <.sidebar_menu_sub_item href="#">Routing</.sidebar_menu_sub_item>
                    <.sidebar_menu_sub_item href="#">Data Fetching</.sidebar_menu_sub_item>
                  </:sub>
                </.sidebar_menu_item>
                <.sidebar_menu_skeleton with_icon />
                <.sidebar_menu_skeleton with_icon />
              </.sidebar_menu>
            </.sidebar_group>

            <:footer>
              <.sidebar_menu>
                <.sidebar_menu_item href="#" tooltip="Account">
                  <:icon><Lucideicons.user /></:icon>
                  Account
                </.sidebar_menu_item>
              </.sidebar_menu>
            </:footer>

            <.sidebar_rail />
          </.sidebar>
          """,
          default_inset("Design Engineering")
        ]
      }
    ]
  end
end
