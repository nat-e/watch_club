defmodule WatchClub.Accounts.UserSettingsTest do
  use WatchClub.DataCase, async: true

  alias WatchClub.Accounts
  alias WatchClub.Accounts.UserSettings

  describe "update_user_settings/*" do
    test "updates the User's audio and subtitle preferences" do
      user = generate(user())

      assert %UserSettings{
               audio_language: :fr,
               subtitle_language: nil,
               languages_without_subtitles: [:en, :fr]
             } =
               Accounts.update_user_settings!(
                 user.settings,
                 %{
                   audio_language: :fr,
                   subtitle_language: nil,
                   languages_without_subtitles: [:en, :fr]
                 },
                 actor: user
               )
    end

    test "forbids updating another User's preferences" do
      user = generate(user())

      user.settings
      |> Accounts.update_user_settings(%{audio_language: :fr}, actor: generate(user()))
      |> assert_has_error(Ash.Error.Forbidden, fn _error -> true end)
    end
  end
end
