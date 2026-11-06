defmodule WatchClubWeb.Playlists.PlaylistsPage.DeletePlaylistModal do
  @moduledoc """
  The confirmation for deleting a Playlist, which says who loses it too.
  """
  use WatchClubWeb, :component

  attr :playlist, Playlist, required: true, doc: "with the `user` of its `accesses`"
  attr :locale, :atom, required: true, doc: "a `UserLocale`"

  def delete_playlist_modal(assigns) do
    ~H"""
    <.modal id="delete-playlist-modal" size="sm" on_close={JS.push("close_delete_playlist")}>
      <:title>{dgettext("playlists", "Delete playlist")}</:title>
      <p>
        {raw(
          dgettext("playlists", "Are you sure you want to delete the playlist %{playlist}?",
            playlist: gtbold(@playlist.name)
          )
        )}
        <span :if={@playlist.accesses != []}>
          {dgettext("playlists", "%{users} will lose it too.",
            users: names(Enum.map(@playlist.accesses, & &1.user), @locale)
          )}
        </span>
      </p>
      <:footer>
        <.button id="delete-playlist-cancel" type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>
        <.button id="delete-playlist-confirm" variant="danger" phx-click="confirm_delete_playlist">
          {dgettext("default", "Delete")}
        </.button>
      </:footer>
    </.modal>
    """
  end

  # "leadelpeut, guigui74 and vinz"
  defp names(users, locale) do
    users
    |> Enum.map(& &1.username)
    |> WatchClub.Cldr.List.to_string!(locale: UserLocale.to_cldr_locale_name(locale))
  end
end
