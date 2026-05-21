defmodule WatchClub.Checks.IsSystemActor do
  @moduledoc """
  A simple check that validates that the actor is the WatchClub.SystemActor struct.

  Use to gate actions that may only be performed by internal background jobs.
  """
  use Ash.Policy.SimpleCheck

  alias WatchClub.SystemActor

  @impl true
  def describe(_options), do: "actor is the system actor"

  @impl true
  def match?(%SystemActor{}, _context, _options), do: true
  def match?(_, _, _), do: false
end
