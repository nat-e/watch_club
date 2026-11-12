defmodule WatchClubWeb.Admin.MediaBrowserPage.RemoveMediaModal do
  @moduledoc """
  Confirmation modal for removing a media from the instance.

  Owner-private to `MediaBrowserPage`. The hardcoded `phx-click` event names
  (`delete_media`, `close_remove_media_modal`) are handled by the owning
  LiveView rather than being a reusable component API.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.UI.Button
  import WatchClubWeb.Components.UI.Modal

  def remove_media_modal(assigns) do
    ~H"""
    <.modal id="remove-media-modal" size="sm" on_close={JS.push("close_remove_media_modal")}>
      <:title>{dgettext("admin_media", "Remove media")}</:title>
      <:description>
        {dgettext(
          "admin_media",
          "Remove this media from Watch Club? Its file stays on disk, so the next import adds it back."
        )}
      </:description>
      <:footer>
        <.button id="cancel-remove-media-button" type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>
        <.button id="confirm-remove-media-button" variant="danger" phx-click="delete_media">
          {dgettext("admin_media", "Remove")}
        </.button>
      </:footer>
    </.modal>
    """
  end
end
