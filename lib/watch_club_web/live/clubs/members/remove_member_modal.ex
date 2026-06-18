defmodule WatchClubWeb.Live.Clubs.Members.RemoveMemberModal do
  use WatchClubWeb, :component

  alias WatchClub.Clubs.Membership

  attr :membership, Membership, required: true

  def remove_member_modal(assigns) do
    ~H"""
    <.modal id="remove-member-modal" on_close={JS.push("close_modals")}>
      <:title>{dgettext("clubs", "Remove club member")}</:title>
      <p>
        {raw(
          dgettext(
            "clubs",
            "Are you sure you want to remove %{username}?",
            username: gtbold(@membership.user.username)
          )
        )}
      </p>
      <p>{dgettext("clubs", "They won't be able to join back without being re-invited.")}</p>
      <:footer>
        <.button id="cancel-remove-member-button" type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>

        <.button id="confirm-remove-member-button" variant="danger" phx-click="confirm_remove_member">
          {dgettext("clubs", "Remove")}
        </.button>
      </:footer>
    </.modal>
    """
  end
end
