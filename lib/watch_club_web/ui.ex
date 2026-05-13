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
      import WatchClubWeb.UI.Button
    end
  end
end
