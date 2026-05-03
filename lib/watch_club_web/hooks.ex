defmodule WatchClubWeb.Hooks do
  defmacro __using__(_opts) do
    quote do
      alias WatchClubWeb.Hooks.CurrentUrl
    end
  end
end
