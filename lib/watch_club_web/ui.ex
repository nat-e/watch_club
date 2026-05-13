defmodule WatchClubWeb.UI do
  @moduledoc """
  Watch Club UI primitives.

  This namespace contains the token-driven UI primitives used by the app.
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
      import Phoenix.Component, except: [form: 1]

      import WatchClubWeb.UI.Flash
      import WatchClubWeb.UI.Form
      import WatchClubWeb.UI.Input
      import WatchClubWeb.UI.Kbd
      import WatchClubWeb.UI.Label
      import WatchClubWeb.UI.Layout
      import WatchClubWeb.UI.Modal
      import WatchClubWeb.UI.RadioGroup
      import WatchClubWeb.UI.Select
      import WatchClubWeb.UI.Table
    end
  end
end
