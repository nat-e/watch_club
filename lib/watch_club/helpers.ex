defmodule WatchClub.Helpers do
  def maybe_date!(nil), do: nil
  def maybe_date!(""), do: nil
  def maybe_date!(date), do: Date.from_iso8601!(date)
end
