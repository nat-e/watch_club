defmodule WatchClub.SystemActor do
  @moduledoc """
  Internal actor used by WatchClub background jobs.

  This is not a User and must only be authorized by explicit system policies.
  """

  defstruct system?: true

  def actor, do: %__MODULE__{}
end
