defmodule WatchClubWeb.Live.Admin.UsersPage.DeleteUserModal do
  use WatchClubWeb, :component

  attr :user, User, required: true

  def delete_user_modal(assigns) do
    ~H"""
    <.modal id="delete-user-modal" size="sm" on_close={JS.push("close_modals")}>
      <:title>{dgettext("admin_users", "Delete user")}</:title>
      <p>
        {raw(
          dgettext(
            "admin_users",
            "Delete %{username}? They can't sign in anymore, and their watch history and playlists are deleted. Their messages and requests stay, shown as from a deleted user. You can't undo this.",
            username: gtbold(@user.username)
          )
        )}
      </p>
      <:footer>
        <.button id="cancel-delete-user-button" type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>
        <.button id="confirm-delete-user-button" variant="danger" phx-click="confirm_delete_user">
          {dgettext("admin_users", "Delete user")}
        </.button>
      </:footer>
    </.modal>
    """
  end
end
