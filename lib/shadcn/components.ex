defmodule Shadcn.Components do
  @moduledoc """
  Aggregator for the UI component library.

  Use it inside your project's `html_helpers/0` to import every component in
  one shot:

      use Shadcn
  """

  defmacro __using__(_opts) do
    quote do
      import Shadcn.Components.Accordion
      import Shadcn.Components.Alert
      import Shadcn.Components.AlertDialog
      import Shadcn.Components.AspectRatio
      import Shadcn.Components.Avatar
      import Shadcn.Components.Badge
      import Shadcn.Components.Breadcrumb
      import Shadcn.Components.ButtonGroup
      import Shadcn.Components.Calendar
      import Shadcn.Components.Card
      import Shadcn.Components.Carousel
      import Shadcn.Components.Chart
      import Shadcn.Components.Checkbox
      import Shadcn.Components.Collapsible
      import Shadcn.Components.Combobox
      import Shadcn.Components.Command
      import Shadcn.Components.ContextMenu
      import Shadcn.Components.Dialog
      import Shadcn.Components.Drawer
      import Shadcn.Components.DropdownMenu
      import Shadcn.Components.Empty
      import Shadcn.Components.Field
      import Shadcn.Components.Flash
      import Shadcn.Components.HoverCard
      import Shadcn.Components.Input
      import Shadcn.Components.InputGroup
      import Shadcn.Components.InputOtp
      import Shadcn.Components.Item
      import Shadcn.Components.Kbd
      import Shadcn.Components.Label
      import Shadcn.Components.Menubar
      import Shadcn.Components.Modal
      import Shadcn.Components.NativeSelect
      import Shadcn.Components.NavigationMenu
      import Shadcn.Components.Pagination
      import Shadcn.Components.Popover
      import Shadcn.Components.Progress
      import Shadcn.Components.RadioGroup
      import Shadcn.Components.Resizable
      import Shadcn.Components.ScrollArea
      import Shadcn.Components.Select
      import Shadcn.Components.Separator
      import Shadcn.Components.Sheet
      import Shadcn.Components.Sidebar
      import Shadcn.Components.Slider
      import Shadcn.Components.Switch
      import Shadcn.Components.Table
      import Shadcn.Components.Tabs
      import Shadcn.Components.Textarea
      import Shadcn.Components.Toggle
      import Shadcn.Components.ToggleGroup
      import Shadcn.Components.Tooltip
    end
  end
end
