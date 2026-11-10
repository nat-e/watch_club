defmodule WatchClub.Shared.UpsertCondition do
  @moduledoc false
  import Ash.Expr

  @doc """
  An `upsert_condition` that updates a stored record only when one of the fields differs from the
  new values, so an unchanged record isn't written.
  """
  def any_changed(fields) do
    fields
    |> Enum.map(&expr(is_distinct_from(^ref(&1), upsert_conflict(^&1))))
    |> Enum.reduce(&expr(^&2 or ^&1))
  end
end
