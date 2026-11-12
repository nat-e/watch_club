defmodule WatchClubWeb.Live.Admin.UsersPage.DeleteInvitationCodeModal do
  use WatchClubWeb, :component

  attr :invitation, InvitationCode, required: true

  def delete_invitation_code_modal(assigns) do
    ~H"""
    <.modal id="delete-invitation-code-modal" on_close={JS.push("close_modals")}>
      <:title>{dgettext("admin_invitations", "Delete invitation")}</:title>
      <p>
        {raw(
          dgettext(
            "admin_invitations",
            "Nobody can sign up with %{code} anymore. Accounts already created with it stay.",
            code: gtbold(@invitation.code)
          )
        )}
      </p>
      <:footer>
        <.button
          id="cancel-delete-invitation-code-button"
          type="button"
          variant="secondary"
          data-modal-close
        >
          {dgettext("default", "Cancel")}
        </.button>
        <.button
          id="confirm-delete-invitation-code-button"
          variant="danger"
          phx-click="confirm_delete_invitation_code"
        >
          {dgettext("admin_invitations", "Delete invitation")}
        </.button>
      </:footer>
    </.modal>
    """
  end
end
