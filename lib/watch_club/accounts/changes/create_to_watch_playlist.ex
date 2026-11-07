defmodule WatchClub.Accounts.Changes.CreateToWatchPlaylist do
  @moduledoc """
  Creates the To Watch Playlist of a new User, named in the locale they registered with.
  """
  use Ash.Resource.Change

  use Gettext, backend: WatchClubWeb.Gettext

  @impl true
  def change(changeset, _opts, _context) do
    # The locale is passed as argument of the User create actions
    locale = Ash.Changeset.get_argument(changeset, :locale)

    Ash.Changeset.after_action(changeset, fn _changeset, user ->
      name =
        Gettext.with_locale(WatchClubWeb.Gettext, language(locale), fn ->
          dgettext("playlists", "To Watch")
        end)

      WatchClub.Playlists.create_playlist!(%{name: name, icon: "popcorn"}, actor: user)

      {:ok, user}
    end)
  end

  # Gettext locales are language-only ("en", "fr"); UserLocale is region-qualified (:en_US).
  defp language(locale), do: locale |> Atom.to_string() |> String.split("_") |> List.first()
end
