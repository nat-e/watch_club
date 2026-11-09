defmodule WatchClubWeb.Helpers.Time do
  alias WatchClub.Accounts.UserLocale

  @spec relative_from_now(DateTime.t(), atom()) :: String.t()
  def relative_from_now(date, locale) do
    date
    |> DateTime.diff(DateTime.utc_now())
    |> WatchClub.Cldr.DateTime.Relative.to_string!(locale: UserLocale.to_cldr_locale_name(locale))
  end

  @doc """
  Returns how long ago a moment was in the past week, like "4 minutes ago", else its UTC date, like
  "Sep 13, 2026".
  """
  @spec relative_or_date!(DateTime.t(), atom()) :: String.t()
  def relative_or_date!(datetime, locale) do
    if DateTime.diff(DateTime.utc_now(), datetime, :day) < 7,
      do: relative_from_now(datetime, locale),
      else:
        WatchClub.Cldr.Date.to_string!(DateTime.to_date(datetime),
          format: :medium,
          locale: cldr_locale(locale)
        )
  end

  @doc """
  Returns the localized time of day in the time zone, like "14:32" or "2:32 PM".
  """
  @spec clock(DateTime.t(), String.t(), atom()) :: String.t()
  def clock(datetime, time_zone, locale) do
    datetime
    |> DateTime.shift_zone!(time_zone)
    |> WatchClub.Cldr.Time.to_string!(format: :short, locale: cldr_locale(locale))
  end

  @doc """
  Returns the day of a moment in the time zone, as a label: "Today", "Yesterday", the weekday in
  the past week, else the date, like "October 21".
  """
  @spec day(DateTime.t(), String.t(), atom()) :: String.t()
  def day(datetime, time_zone, locale) do
    date = local_date(datetime, time_zone)
    today = local_date(DateTime.utc_now(), time_zone)

    if today.year == date.year,
      do: recent_day(date, today, locale, :MMMMd),
      else: recent_day(date, today, locale, :yMMMMd)
  end

  @doc """
  Returns when a moment was in the time zone, in a few characters: the time of day for today,
  else "Yesterday", the weekday in the past week, or the short date, like "10/21/26".
  """
  @spec clock_or_day(DateTime.t(), String.t(), atom()) :: String.t()
  def clock_or_day(datetime, time_zone, locale) do
    date = local_date(datetime, time_zone)
    today = local_date(DateTime.utc_now(), time_zone)

    if date == today,
      do: clock(datetime, time_zone, locale),
      else: recent_day(date, today, locale, :short)
  end

  # "Today", "Yesterday", the weekday in the past week, else the date in the format
  defp recent_day(date, today, locale, format) do
    locale = cldr_locale(locale)

    case Date.diff(today, date) do
      days when days in [0, 1] ->
        -days
        |> WatchClub.Cldr.DateTime.Relative.to_string!(unit: :day, locale: locale)
        |> String.capitalize()

      days when days < 7 ->
        date
        |> WatchClub.Cldr.Date.to_string!(format: "EEEE", locale: locale)
        |> String.capitalize()

      _days ->
        WatchClub.Cldr.Date.to_string!(date, format: format, locale: locale)
    end
  end

  @doc """
  Returns the date of a moment in the time zone.
  """
  @spec local_date(DateTime.t(), String.t()) :: Date.t()
  def local_date(datetime, time_zone),
    do: datetime |> DateTime.shift_zone!(time_zone) |> DateTime.to_date()

  defp cldr_locale(locale), do: UserLocale.to_cldr_locale_name(locale)

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
  Returns a localized number of minutes in hours and minutes, like "52 min" or "2 hr 9 min", or
  nil without any, as TMDB gives for an unknown runtime.
  """
  @spec minutes(non_neg_integer() | nil, atom()) :: String.t() | nil
  def minutes(minutes, _locale) when minutes in [nil, 0], do: nil

  def minutes(minutes, locale) do
    minutes
    |> WatchClub.Cldr.Unit.new!(:minute)
    |> WatchClub.Cldr.Unit.decompose([:hour, :minute])
    |> WatchClub.Cldr.Unit.to_string!(
      style: :short,
      list_options: [format: :unit_narrow],
      locale: UserLocale.to_cldr_locale_name(locale)
    )
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
