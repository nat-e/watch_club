defmodule WatchClubWeb.Admin.MediaSources.RunImportModal do
  @moduledoc """
  Confirm modal for triggering a `Media Import`. Hosts the only Refresh
  metadata switch in the UI — cards and history headers do not expose it.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Media.SourceIdentifier

  attr :media_source, Source, required: true

  def run_import_modal(assigns) do
    assigns =
      assign(
        assigns,
        :form,
        to_form(%{"media_source_id" => assigns.media_source.id}, as: :run_import)
      )

    ~H"""
    <.modal id="run-import-modal" size="sm" on_close={JS.push("close_modals")}>
      <:title>{dgettext("admin_media_imports", "Run media import")}</:title>
      <:description>
        {raw(
          dgettext("admin_media_imports", "Start a new import of %{name} from:",
            name: gtbold(@media_source.name)
          )
        )}
        <.source_identifier media_source={@media_source} />
      </:description>

      <.form for={@form} id="run-import-form" phx-submit="confirm_run_import">
        <.input field={@form[:media_source_id]} type="hidden" />

        <label
          for={@form[:refresh_metadata].id}
          class="flex cursor-pointer items-start gap-related rounded-md border border-border bg-surface p-group"
        >
          <.checkbox field={@form[:refresh_metadata]} value="true" class="mt-1" />
          <.stack space="tight">
            <span class="text-sm font-medium text-text">
              {dgettext("admin_media_imports", "Refresh metadata")}
            </span>
            <span class="text-xs text-text-muted">
              {dgettext(
                "admin_media_imports",
                "When enabled, the media will be re-computed and potentially re-matched to another content."
              )}
            </span>
          </.stack>
        </label>

        <:action>
          <.button id="cancel-run-import-button" type="button" variant="secondary" data-modal-close>
            {dgettext("default", "Cancel")}
          </.button>
          <.button id="confirm-run-import-button" type="submit" variant="primary">
            <:icon position="start"><Lucideicons.play /></:icon>
            {dgettext("admin_media_imports", "Run import")}
          </.button>
        </:action>
      </.form>
    </.modal>
    """
  end
end
