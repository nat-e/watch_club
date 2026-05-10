defmodule WatchClub.Accounts.UserLocale do
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      :en_US,
      :fr_FR
    ]

  def translated_label(:en_US), do: dgettext("locales", "English (US)")
  def translated_label(:fr_FR), do: dgettext("locales", "French")

  def iso_639_1(:en_US), do: "en"
  def iso_639_1(:fr_FR), do: "fr"
  def iso_3166_1(:en_US), do: "US"
  def iso_3166_1(:fr_FR), do: "FR"
end
