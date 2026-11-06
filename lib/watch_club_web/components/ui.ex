defmodule WatchClubWeb.Components.UI do
  @moduledoc """
  Watch Club UI primitives.

  This namespace contains the token-driven UI primitives used by the app.
  """

  defmacro __using__(_opts) do
    quote do
      import WatchClubWeb.Components.UI.Alert
      import WatchClubWeb.Components.UI.Avatar
      import WatchClubWeb.Components.UI.Badge
      import WatchClubWeb.Components.UI.Badges
      import WatchClubWeb.Components.UI.Button
      import WatchClubWeb.Components.UI.Checkbox
      import WatchClubWeb.Components.UI.FilterChip
      import WatchClubWeb.Components.UI.DropdownMenu
      import WatchClubWeb.Components.UI.Empty
      import Phoenix.Component, except: [form: 1]

      import WatchClubWeb.Components.UI.Flash
      import WatchClubWeb.Components.UI.Form
      import WatchClubWeb.Components.UI.InfiniteScroll
      import WatchClubWeb.Components.UI.Input
      import WatchClubWeb.Components.UI.Kbd
      import WatchClubWeb.Components.UI.Label
      import WatchClubWeb.Components.UI.Layout
      import WatchClubWeb.Components.UI.LucideIcon
      import WatchClubWeb.Components.UI.Modal
      import WatchClubWeb.Components.UI.ProgressBar
      import WatchClubWeb.Components.UI.RadioGroup
      import WatchClubWeb.Components.UI.ReorderableList
      import WatchClubWeb.Components.UI.ScrollRow
      import WatchClubWeb.Components.UI.SegmentedControl
      import WatchClubWeb.Components.UI.Select
      import WatchClubWeb.Components.UI.Table
      import WatchClubWeb.Components.UI.Tooltip
      import WatchClubWeb.Components.UI.Typography
      import WatchClubWeb.Components.UI.UnreadBadge
    end
  end
end
