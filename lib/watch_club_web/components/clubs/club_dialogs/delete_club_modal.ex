defmodule WatchClubWeb.Components.Clubs.ClubDialogs.DeleteClubModal do
  @moduledoc """
  Delete club modal owned by `ClubDialogsLive`.

  Owner-private to `ClubDialogsLive`. The hardcoded phx-click is handled by the owning
  LiveComponent rather than reusable component API.
  """
  use WatchClubWeb, :component

  attr :club, Club, required: true
  attr :myself, :any, required: true

  def delete_club_modal(assigns) do
    ~H"""
    <.modal id="delete-club-modal" size="sm" on_close={JS.push("close_modals", target: @myself)}>
      <:title>{dgettext("clubs", "Delete club")}</:title>
      <p>
        {raw(
          dgettext(
            "clubs",
            "Are you sure you want to delete %{club_name}?",
            club_name: gtbold(@club.name)
          )
        )}
      </p>
      <p>
        {dgettext(
          "clubs",
          "All the members will be removed and the data will be deleted permanently."
        )}
      </p>
      <:footer>
        <.button id="cancel-delete-club-button" type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>

        <.button
          id="confirm-delete-club-button"
          variant="danger"
          phx-click="delete_club"
          phx-value-club_id={@club.id}
          phx-target={@myself}
        >
          {dgettext("default", "Delete")}
        </.button>
      </:footer>
    </.modal>
    """
  end
end
