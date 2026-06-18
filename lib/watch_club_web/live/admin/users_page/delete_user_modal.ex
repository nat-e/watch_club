defmodule WatchClubWeb.Live.Admin.UsersPage.DeleteUserModal do
  use WatchClubWeb, :component

  attr :user, User, required: true

  def delete_user_modal(assigns) do
    ~H"""
    <.modal id="delete-user-modal" on_close={JS.push("close_modals")}>
      <:title>{dgettext("admin_users", "Delete user")}</:title>
      <p>
        {raw(
          dgettext(
            "admin_users",
            "Are you sure you want to delete %{username}? They will not be able to access Watch Club and all their history will be erased.",
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
