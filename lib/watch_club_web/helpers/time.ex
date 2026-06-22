defmodule WatchClubWeb.Helpers.Time do
  alias WatchClub.Accounts.UserLocale

  @spec relative_from_now(DateTime.t(), atom()) :: String.t()
  def relative_from_now(date, locale) do
    date
    |> DateTime.diff(DateTime.utc_now())
    |> WatchClub.Cldr.DateTime.Relative.to_string!(locale: UserLocale.to_cldr_locale_name(locale))
  end

  @doc """
  Returns a String representing the year of a Date, if a Date is provided.
  """
  @spec maybe_year(Date.t() | nil) :: String.t() | nil
  def maybe_year(%Date{year: year}), do: Integer.to_string(year)
  def maybe_year(_), do: nil

  @doc """
  Returns a localized string for a pretty duration like "3 seconds", "19 minutes", ...
  """
  @spec pretty_duration(number(), atom()) :: String.t()
  def pretty_duration(duration_seconds, locale) when is_number(duration_seconds) do
    seconds = trunc(duration_seconds)

    {value, unit} =
      cond do
        seconds < 60 -> {seconds, :second}
        seconds < 3600 -> {div(seconds, 60), :minute}
        true -> {div(seconds, 3600), :hour}
      end

    WatchClub.Cldr.Unit.to_string!(value,
      unit: unit,
      style: :short,
      locale: UserLocale.to_cldr_locale_name(locale)
    )
  end
end
