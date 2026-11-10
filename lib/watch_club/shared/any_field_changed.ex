defmodule WatchClub.Shared.AnyFieldChanged do
  @moduledoc false
  # Not `expr/1`, which this module defines
  import Ash.Expr, only: [ref: 1]
  require Ash.Expr

  @doc """
  An `upsert_condition` that updates a stored record only when one of the fields differs from the
  new values, so an unchanged record isn't written.
  """
  def expr(fields) do
    fields
    |> Enum.map(&Ash.Expr.expr(is_distinct_from(^ref(&1), upsert_conflict(^&1))))
    |> Enum.reduce(&Ash.Expr.expr(^&2 or ^&1))
  end
end
