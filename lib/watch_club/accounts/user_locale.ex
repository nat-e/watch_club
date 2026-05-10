defmodule WatchClub.Accounts.UserLocale do
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      :en_US,
      :fr_FR
    ]

  def translated_label(:en_US), do: dgettext("locales", "English (US)")
  def translated_label(:fr_FR), do: dgettext("locales", "French")
end
