defmodule WatchClub.Accounts.UserLocale do
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      :en_US,
      :fr_FR
    ]

  def translated_label(:en_US), do: dgettext("locales", "English (US)")
  def translated_label(:fr_FR), do: dgettext("locales", "French")

  def default, do: values() |> List.first()

  def cldr_locale_names, do: values() |> Enum.map(&to_cldr_locale_name/1) |> Enum.uniq()

  def to_cldr_locale_name(locale), do: locale |> split() |> List.first()

  def split(locale), do: locale |> Atom.to_string() |> String.split("_")
end
