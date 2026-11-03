defmodule WatchClubWeb.Components.Clubs.ClubDialogs.CreateClubModal do
  @moduledoc """
  Create club modal owned by `ClubDialogsLive`.

  Owner-private to `ClubDialogsLive`. The hardcoded phx-* event names are handled by the
  owning LiveComponent rather than reusable component API.
  """
  use WatchClubWeb, :component

  attr :form, Phoenix.HTML.Form, required: true
  attr :myself, :any, required: true

  def create_club_modal(assigns) do
    ~H"""
    <.modal id="create-club-modal" size="sm" on_close={JS.push("close_modals", target: @myself)}>
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
      >
        <.field field={@form[:name]} label={dgettext("clubs", "Club name")} type="text" />
        <:action>
          <.button id="create-club-submit-button" type="submit" class="w-full">
            {dgettext("default", "Create")}
          </.button>
        </:action>
      </.form>
    </.modal>
    """
  end
end
