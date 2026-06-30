defmodule WatchClub.Helpers do
  @spec maybe_date!(String.t() | nil) :: Date.t() | nil
  def maybe_date!(nil), do: nil
  def maybe_date!(""), do: nil
  def maybe_date!(date), do: Date.from_iso8601!(date)

  @spec maybe_datetime!(String.t() | nil) :: DateTime.t() | nil
  def maybe_datetime!(nil), do: nil
  def maybe_datetime!(""), do: nil

  def maybe_datetime!(value) do
    {:ok, datetime, 0} = DateTime.from_iso8601(value)
    datetime
  end
end
