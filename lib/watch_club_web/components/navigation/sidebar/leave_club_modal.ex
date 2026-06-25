defmodule WatchClubWeb.Components.Navigation.Sidebar.LeaveClubModal do
  @moduledoc """
  Leave club modal owned by the sidebar.

  Owner-private to `SidebarLive`. The hardcoded phx-click is a global sidebar
  event handled by the owning LiveComponent rather than reusable component API.
  """
  use WatchClubWeb, :component

  attr :membership, Membership, required: true
  attr :myself, :any, required: true

  def leave_club_modal(assigns) do
    ~H"""
    <.modal id="leave-club-modal" size="sm" on_close={JS.push("close_modals", target: @myself)}>
      <:title>{dgettext("clubs", "Leave club")}</:title>
      <p>
        {raw(
          dgettext(
            "clubs",
            "Are you sure you want to leave %{club_name}?",
            club_name: gtbold(@membership.club.name)
          )
        )}
      </p>
      <p>
        {dgettext(
          "clubs",
          "You will loose access to the library and will not be able to join back unless re-invited"
        )}
      </p>
      <:footer>
        <.button id="cancel-leave-club-button" type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>

        <.button
          id="confirm-leave-club-button"
          variant="danger"
          phx-click="leave_club"
          phx-value-membership_id={@membership.id}
          phx-target={@myself}
        >
          {dgettext("clubs", "Leave")}
        </.button>
      </:footer>
    </.modal>
    """
  end
end
