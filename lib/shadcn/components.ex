defmodule Shadcn.Components do
  @moduledoc """
  Aggregator for the Shadcn components used by the app.

  Use it inside your project's `html_helpers/0` to import the active component
  set in one shot:

      use Shadcn
  """

  defmacro __using__(_opts) do
    quote do
      import Shadcn.Components.ButtonGroup
      import Shadcn.Components.Checkbox
      import Shadcn.Components.Dialog
      import Shadcn.Components.DropdownMenu
      import Shadcn.Components.Empty
      import Shadcn.Components.Field
      import Shadcn.Components.Flash
      import Shadcn.Components.Input
      import Shadcn.Components.Kbd
      import Shadcn.Components.Label
      import Shadcn.Components.Modal
      import Shadcn.Components.RadioGroup
      import Shadcn.Components.Select
      import Shadcn.Components.Sidebar
      import Shadcn.Components.Skeleton
      import Shadcn.Components.Table
    end
  end
end
