defmodule Shadcn.Components do
  @moduledoc """
  Aggregator for the Shadcn components used by the app.

  Use it inside your project's `html_helpers/0` to import legacy Shadcn
  components that have not yet moved to `WatchClubWeb.UI`:

      use Shadcn
  """

  defmacro __using__(_opts) do
    quote do
      import Shadcn.Components.Skeleton
    end
  end
end
