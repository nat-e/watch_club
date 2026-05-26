defmodule WatchClub.Shared.Oban.AshObanActorPersister do
  @moduledoc false

  use AshOban.ActorPersister

  alias WatchClub.SystemActor

  @impl true
  def store(%SystemActor{}), do: %{"type" => "system"}

  @impl true
  def lookup(%{"type" => "system"}), do: {:ok, SystemActor.actor()}
  def lookup(nil), do: {:ok, SystemActor.actor()}
end
