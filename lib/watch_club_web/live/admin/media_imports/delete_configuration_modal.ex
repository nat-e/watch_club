defmodule WatchClubWeb.Admin.MediaImports.DeleteConfigurationModal do
  @moduledoc """
  Confirm modal for destroying a `Media Import Configuration`. Past
  `Media Imports` and any `Media` previously imported by this configuration
  remain on the instance.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Media.FilesystemPath

  alias WatchClub.Media.{ImportConfiguration, MediaType}

  attr :configuration, ImportConfiguration, required: true

  def delete_configuration_modal(assigns) do
    ~H"""
    <.modal id="delete-import-modal" on_close={JS.push("close_modals")}>
      <:title>{dgettext("admin_media_imports", "Delete configured import")}</:title>
      <.stack space="related">
        <p class="text-sm text-text">
          {raw(
            dgettext("admin_media_imports", "This will delete the %{label} import for:",
              label: gtbold(MediaType.translated_plural_label(@configuration.media_type))
            )
          )}
        </p>
        <.filesystem_path path={@configuration.filesystem_path} class="self-start" />
        <p class="text-sm text-text-muted">
          {dgettext(
            "admin_media_imports",
            "All media previously imported will not be removed from the instance."
          )}
        </p>
      </.stack>

      <:footer>
        <.button id="cancel-delete-import-button" type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>
        <.button
          id="confirm-delete-import-button"
          variant="danger"
          phx-click="confirm_delete_configuration"
          phx-value-id={@configuration.id}
        >
          {dgettext("admin_media_imports", "Delete import")}
        </.button>
      </:footer>
    </.modal>
    """
  end
end
