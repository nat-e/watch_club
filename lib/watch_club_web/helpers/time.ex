defmodule WatchClubWeb.Helpers.Time do
  alias WatchClub.Accounts.UserLocale

  @four_weeks_in_seconds 2_419_200

  @spec relative_from_now(DateTime.t(), atom()) :: String.t()
  def relative_from_now(date, locale) do
    diff = DateTime.diff(DateTime.utc_now(), date)
    cldr_locale_name = UserLocale.to_cldr_locale_name(locale)

    cond do
      diff < 60 ->
        format_relative(0, :second, cldr_locale_name)

      diff < 120 ->
        format_relative(-1, :minute, cldr_locale_name)

      diff < 3600 ->
        format_relative(-div(diff, 60), :minute, cldr_locale_name)

      diff < 7200 ->
        format_relative(-1, :hour, cldr_locale_name)

      diff < 86_400 ->
        format_relative(-div(diff, 3600), :hour, cldr_locale_name)

      diff < 172_800 ->
        format_relative(-1, :day, cldr_locale_name)

      diff < 604_800 ->
        format_relative(-div(diff, 86_400), :day, cldr_locale_name)

      diff < 1_209_600 ->
        format_relative(-1, :week, cldr_locale_name)

      diff < @four_weeks_in_seconds ->
        format_relative(-div(diff, 604_800), :week, cldr_locale_name)

      true ->
        format_date(date, cldr_locale_name)
    end
  end

  defp format_relative(value, unit, locale) do
    WatchClub.Cldr.DateTime.Relative.to_string!(value, unit: unit, locale: locale)
  end

  defp format_date(date, locale) do
    date |> DateTime.to_date() |> WatchClub.Cldr.Date.to_string!(format: :medium, locale: locale)
  end
end
