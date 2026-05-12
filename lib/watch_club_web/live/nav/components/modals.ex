defmodule WatchClubWeb.Live.Nav.Components.Modals do
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Forms

  attr :form, Phoenix.HTML.Form, required: true
  attr :myself, :any, required: true

  def create_club_modal(assigns) do
    ~H"""
    <.modal id="create-club-modal" open={true} on_close={JS.push("close_modals", target: @myself)}>
      <.dialog>
        <:title>{dgettext("clubs", "Create new club")}</:title>
        <:description>
          {dgettext(
            "clubs",
            "Create a new club to share your favorite movies and TV shows with your friends."
          )}
        </:description>
        <.form
          :if={@form}
          for={@form}
          id="create-club-form"
          phx-change="validate_create_club"
          phx-submit="create_club"
          phx-target={@myself}
          class="flex flex-col gap-6"
        >
          <div class="flex flex-col gap-2">
            <.label field={@form[:name]}>{dgettext("clubs", "Club name")}</.label>
            <.input
              field={@form[:name]}
              type="text"
              phx-debounce="blur"
            />
            <.field_errors field={@form[:name]} />
          </div>
          <.button type="submit" class="w-full">
            {dgettext("default", "Create")}
          </.button>
        </.form>
      </.dialog>
    </.modal>
    """
  end

  attr :club, Club, required: true
  attr :myself, :any, required: true

  def delete_club_modal(assigns) do
    ~H"""
    <.modal id="delete-club-modal" open={true} on_close={JS.push("close_modals", target: @myself)}>
      <.dialog>
        <:title>{dgettext("clubs", "Delete club")}</:title>
        <div class="flex flex-col gap-4">
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
          <div class="flex justify-end gap-2">
            <.button
              type="button"
              class="w-fit self-end"
              variant="secondary"
              phx-click="close_modals"
              phx-target={@myself}
            >
              {dgettext("default", "Cancel")}
            </.button>

            <.button
              class="w-fit self-end"
              variant="danger"
              phx-click="delete_club"
              phx-value-club_id={@club.id}
              phx-target={@myself}
            >
              {dgettext("default", "Delete")}
            </.button>
          </div>
        </div>
      </.dialog>
    </.modal>
    """
  end

  attr :membership, Membership, required: true
  attr :myself, :any, required: true

  def leave_club_modal(assigns) do
    ~H"""
    <.modal id="leave-club-modal" open={true} on_close={JS.push("close_modals", target: @myself)}>
      <.dialog>
        <:title>{dgettext("clubs", "Leave club")}</:title>
        <p>
          {raw(
            dgettext(
              "clubs",
              "Are you sure you want to leave %{club_name}?",
              name: gtbold(@club.name)
            )
          )}
        </p>
        <p>
          {dgettext(
            "clubs",
            "You will loose access to the library and will not be able to join back unless re-invited"
          )}
        </p>
        <div class="flex justify-end gap-2">
          <.button
            type="button"
            class="w-fit self-end"
            variant="secondary"
            phx-click="close_modals"
            phx-target={@myself}
          >
            {dgettext("default", "Cancel")}
          </.button>

          <.button
            class="w-fit self-end"
            variant="danger"
            phx-click="leave_club"
            phx-value-membership_id={@membership.id}
            phx-target={@myself}
          >
            {dgettext("clubs", "Leave")}
          </.button>
        </div>
      </.dialog>
    </.modal>
    """
  end
end
