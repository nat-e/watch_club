defmodule WatchClub.Cldr do
  alias WatchClub.Accounts.UserLocale

  @locales UserLocale.cldr_locale_names()
  @default_locale UserLocale.default() |> UserLocale.to_cldr_locale_name()

  use Cldr,
    otp_app: :watch_club,
    default_locale: @default_locale,
    locales: @locales,
    providers: [Cldr.Number, Cldr.Calendar, Cldr.DateTime, Cldr.Language, Cldr.List, Cldr.Unit]
end
