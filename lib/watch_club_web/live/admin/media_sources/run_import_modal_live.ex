defmodule WatchClubWeb.Admin.MediaSources.RunImportModalLive do
  @moduledoc """
  Confirm modal for triggering a `Media Import`, where the Instance Administrator chooses which
  files it processes and, for Videos, whether it regenerates their Scrubbing Thumbnails and
  Markers. Sends `:media_import_started` to its LiveView once the Media Import has started.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Media.SourceIdentifier

  attr :id, :string, required: true
  attr :media_source, Source, required: true
  attr :current_user, User, required: true

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :form, to_form(%{"files_to_process" => "new"}, as: :run_import))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
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

        <.form
          for={@form}
          id="run-import-form"
          phx-change="change"
          phx-submit="start"
          phx-target={@myself}
        >
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

          <%!-- New files get them anyway --%>
          <label
            :if={@media_source.media_type in [:movie, :tv_show_episode, :sports_event]}
            for="run-import-regenerate"
            class="group/regenerate flex items-start gap-related has-disabled:cursor-not-allowed"
          >
            <.checkbox
              id="run-import-regenerate"
              field={@form[:regenerate_thumbnails_and_markers?]}
              disabled={@form[:files_to_process].value == "new"}
              class="mt-0.5"
            />
            <.stack space="tight" class="min-w-0 group-has-disabled/regenerate:opacity-40">
              <span class="text-sm font-semibold text-text">
                {dgettext("admin_media_imports", "Regenerate thumbnails and markers")}
              </span>
              <span class="text-xs text-text-muted">
                {dgettext("admin_media_imports", "Even for files that haven't changed.")}
              </span>
            </.stack>
          </label>

          <:action>
            <.button
              id="cancel-run-import-button"
              type="button"
              variant="secondary"
              data-modal-close
            >
              {dgettext("default", "Cancel")}
            </.button>
            <.button id="confirm-run-import-button" type="submit" variant="primary">
              <:icon position="start"><Lucideicons.play /></:icon>
              {dgettext("admin_media_imports", "Run import")}
            </.button>
          </:action>
        </.form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("change", %{"run_import" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: :run_import))}
  end

  # The Run import button is disabled while a Media Import is processing
  def handle_event("start", %{"run_import" => params}, socket) do
    MediaSources.start_media_import!(socket.assigns.media_source.id, params,
      actor: socket.assigns.current_user
    )

    send(self(), :media_import_started)
    {:noreply, socket}
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
