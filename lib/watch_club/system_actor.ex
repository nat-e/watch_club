defmodule WatchClub.SystemActor do
  @moduledoc """
  Internal actor used by WatchClub background jobs.

  This is not a User and must only be authorized by explicit system policies.
  """

  @type t :: %__MODULE__{system?: true}

  defstruct system?: true

  @spec actor() :: t()
  def actor, do: %__MODULE__{}
end
