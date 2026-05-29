defmodule WatchClubWeb.Admin.MediaSources.DeleteMediaSourceModal do
  @moduledoc """
  Confirm modal for destroying a `Media Source`. Past `Media Imports` and any
  `Media` previously imported by this `Media Source` remain on the instance.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Media.SourceIdentifier

  alias WatchClub.MediaSources.Source

  attr :media_source, Source, required: true

  def delete_media_source_modal(assigns) do
    ~H"""
    <.modal id="delete-media-source-modal" on_close={JS.push("close_modals")}>
      <:title>{dgettext("admin_media_imports", "Delete Media Source")}</:title>
      <.stack space="related">
        <p class="text-sm text-text">
          {raw(
            dgettext("admin_media_imports", "This will delete the Media Source %{name}:",
              name: gtbold(@media_source.name)
            )
          )}
        </p>
        <.source_identifier media_source={@media_source} />
        <p class="text-sm text-text-muted">
          {dgettext(
            "admin_media_imports",
            "All media previously imported will not be removed from the instance."
          )}
        </p>
      </.stack>

      <:footer>
        <.button
          id="cancel-delete-media-source-button"
          type="button"
          variant="secondary"
          data-modal-close
        >
          {dgettext("default", "Cancel")}
        </.button>
        <.button
          id="confirm-delete-media-source-button"
          variant="danger"
          phx-click="confirm_delete_media_source"
          phx-value-id={@media_source.id}
        >
          {dgettext("admin_media_imports", "Delete Media Source")}
        </.button>
      </:footer>
    </.modal>
    """
  end
end
