defmodule WatchClub.Accounts.TrackLanguage do
  @moduledoc """
  A language a User can choose for audio and subtitles in their User Preferences.

  Values are the ISO 639-1 codes that `WatchClub.Languages.to_code/1` returns.
  """

  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum, values: [:en, :fr]

  def translated_label(:en), do: dgettext("track_languages", "English")
  def translated_label(:fr), do: dgettext("track_languages", "French")
end
