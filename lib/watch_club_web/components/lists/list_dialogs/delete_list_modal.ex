defmodule WatchClubWeb.Components.Lists.ListDialogs.DeleteListModal do
  @moduledoc """
  Confirmation modal for deleting a user's list.
  """
  use WatchClubWeb, :component

  attr :list, ContentList, required: true
  attr :myself, :any, required: true

  def delete_list_modal(assigns) do
    ~H"""
    <.modal id="delete-list-modal" size="sm" on_close={JS.push("close_modals", target: @myself)}>
      <:title>{dgettext("lists", "Delete list")}</:title>
      <p>
        {raw(
          dgettext("lists", "Are you sure you want to delete the list %{list_name}?",
            list_name: gtbold(@list.name)
          )
        )}
      </p>
      <:footer>
        <.button id="cancel-delete-list-button" type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>
        <.button
          id="confirm-delete-list-button"
          variant="danger"
          phx-click="delete_list"
          phx-value-list_id={@list.id}
          phx-target={@myself}
        >
          {dgettext("default", "Delete")}
        </.button>
      </:footer>
    </.modal>
    """
  end
end
