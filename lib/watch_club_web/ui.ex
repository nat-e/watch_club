defmodule WatchClubWeb.UI do
  @moduledoc """
  Watch Club UI primitives.

  This namespace is the token-driven replacement layer for new UI code. Import it
  explicitly while legacy shadcn components are still globally available.
  """

  defmacro __using__(_opts) do
    quote do
      import WatchClubWeb.UI.Alert
      import WatchClubWeb.UI.Avatar
      import WatchClubWeb.UI.Badges
      import WatchClubWeb.UI.Button
      import WatchClubWeb.UI.Checkbox
      import WatchClubWeb.UI.DropdownMenu
      import WatchClubWeb.UI.Empty
      import WatchClubWeb.UI.Flash
      import WatchClubWeb.UI.Input
      import WatchClubWeb.UI.Kbd
      import WatchClubWeb.UI.Label
      import WatchClubWeb.UI.Modal
      import WatchClubWeb.UI.RadioGroup
      import WatchClubWeb.UI.Select
    end
  end
end
