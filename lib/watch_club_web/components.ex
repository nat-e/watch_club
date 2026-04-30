defmodule WatchClubWeb.Components do
  defmacro __using__(_opts) do
    quote do
      import WatchClubWeb.Components.Forms.FieldErrors
    end
  end
end
