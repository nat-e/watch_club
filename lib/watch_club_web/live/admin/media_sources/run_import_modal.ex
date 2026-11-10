defmodule WatchClubWeb.Admin.MediaSources.RunImportModal do
  @moduledoc """
  Confirm modal for triggering a `Media Import`, where the Instance Administrator chooses which
  files it processes.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Media.SourceIdentifier

  attr :media_source, Source, required: true

  def run_import_modal(assigns) do
    assigns =
      assign(
        assigns,
        :form,
        to_form(%{"media_source_id" => assigns.media_source.id, "files_to_process" => "new"},
          as: :run_import
        )
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

        <div class="flex flex-col gap-related">
          <.label id="run-import-files-label">
            {dgettext("admin_media_imports", "Process")}
          </.label>
          <.radio_group
            field={@form[:files_to_process]}
            aria-labelledby="run-import-files-label"
            variant="card"
          >
            <:item
              :for={{value, label, description} <- files_to_process_options()}
              value={value}
              class="flex items-center gap-related p-group"
            >
              <.stack space="tight" class="min-w-0 flex-1">
                <span class="text-sm font-semibold text-text">{label}</span>
                <span class="text-xs text-text-muted">{description}</span>
              </.stack>
              <Lucideicons.check class="size-icon-sm shrink-0 text-accent opacity-0 transition-opacity group-has-checked/radio-card:opacity-100" />
            </:item>
          </.radio_group>
        </div>

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

  defp files_to_process_options do
    [
      {:new, dgettext("admin_media_imports", "New files only"),
       dgettext("admin_media_imports", "Only files not imported yet.")},
      {:new_and_unmatched, dgettext("admin_media_imports", "New and unmatched files"),
       dgettext("admin_media_imports", "Also retries files that couldn't be matched.")},
      {:all, dgettext("admin_media_imports", "All files"),
       dgettext(
         "admin_media_imports",
         "Reads every file again and matches it again. Manual matches are kept."
       )}
    ]
  end
end
