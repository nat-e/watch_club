defmodule WatchClubWeb.Helpers.Time do
  use Gettext, backend: WatchClubWeb.Gettext

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
  Returns a localized date like "July 8, 2027".
  """
  @spec long_date(Date.t(), atom()) :: String.t()
  def long_date(%Date{} = date, locale) do
    WatchClub.Cldr.Date.to_string!(date,
      format: :long,
      locale: UserLocale.to_cldr_locale_name(locale)
    )
  end

  @doc """
  Returns how long a Movie or a TV Show Episode lasts, like "52 minutes" or "2h 9m".
  """
  @spec runtime(non_neg_integer() | nil) :: String.t() | nil
  def runtime(nil), do: nil

  def runtime(minutes) when minutes < 60,
    do: dngettext("contents", "%{count} minute", "%{count} minutes", minutes)

  def runtime(minutes) do
    case rem(minutes, 60) do
      0 ->
        dgettext("contents", "%{hours}h", hours: div(minutes, 60))

      rest ->
        dgettext("contents", "%{hours}h %{minutes}m", hours: div(minutes, 60), minutes: rest)
    end
  end

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
