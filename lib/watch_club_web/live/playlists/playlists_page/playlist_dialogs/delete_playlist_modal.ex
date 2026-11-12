defmodule WatchClubWeb.Playlists.PlaylistsPage.PlaylistDialogs.DeletePlaylistModal do
  @moduledoc """
  The confirmation for deleting a Playlist, which says who loses it too. Owner-private to
  `PlaylistDialogsLive`, which handles its events.
  """
  use WatchClubWeb, :component

  attr :playlist, Playlist, required: true, doc: "with the `user` of its `accesses`"
  attr :current_user, User, required: true
  attr :myself, :any, required: true

  def delete_playlist_modal(assigns) do
    ~H"""
    <.modal id="delete-playlist-modal" size="sm" on_close={JS.push("close", target: @myself)}>
      <:title>{dgettext("playlists", "Delete playlist")}</:title>
      <p>
        {raw(
          dgettext("playlists", "Delete %{playlist}? You can't undo this.",
            playlist: gtbold(@playlist.name)
          )
        )}
        <span :if={@playlist.accesses != []}>
          {dgettext("playlists", "%{users} will lose it too.",
            users: Usernames.join(Enum.map(@playlist.accesses, & &1.user), @current_user)
          )}
        </span>
      </p>
      <:footer>
        <.button id="delete-playlist-cancel" type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>
        <.button
          id="delete-playlist-confirm"
          variant="danger"
          phx-click="confirm_delete"
          phx-target={@myself}
        >
          {dgettext("default", "Delete")}
        </.button>
      </:footer>
    </.modal>
    """
  end
end
