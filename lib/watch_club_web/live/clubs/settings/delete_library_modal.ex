defmodule WatchClubWeb.Clubs.Settings.DeleteLibraryModal do
  @moduledoc """
  Delete library modal for the club settings page.
  """
  use WatchClubWeb, :component

  attr :library, Library, required: true

  def delete_library_modal(assigns) do
    ~H"""
    <.modal id="delete-library-modal" size="sm" on_close={JS.push("close_modals")}>
      <:title>{dgettext("clubs", "Delete %{library_name}?", library_name: @library.name)}</:title>
      <p>
        {dgettext("clubs", "This will remove the library from the club.")}
      </p>
      <p class="text-text-muted text-sm">
        {dgettext(
          "clubs",
          "The underlying content records will not be deleted."
        )}
      </p>
      <:footer>
        <.button id="cancel-delete-library-button" type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>
        <.button
          id="confirm-delete-library-button"
          variant="danger"
          phx-click="confirm_delete_library"
        >
          {dgettext("clubs", "Delete library")}
        </.button>
      </:footer>
    </.modal>
    """
  end
end
