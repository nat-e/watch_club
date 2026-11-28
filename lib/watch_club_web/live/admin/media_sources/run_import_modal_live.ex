defmodule WatchClubWeb.Admin.MediaSources.RunImportModalLive do
  @moduledoc """
  Confirm modal for triggering a `Media Import`, where the Instance Administrator chooses whether
  it reads every file again and, for Videos, whether it regenerates their Scrubbing Thumbnails and
  Markers.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Media.SourceIdentifier

  alias WatchClubWeb.Hooks.Flash

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(
         MediaSources.form_to_start_media_import(actor: assigns.current_user, as: "run_import")
       )
     end)}
  end

  attr :id, :string, required: true
  attr :media_source, Source, required: true
  attr :current_user, User, required: true
  attr :on_close, :any, required: true, doc: "a function the dialog calls once it closes"

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.modal id="run-import-modal" size="sm" on_close={JS.push("close", target: @myself)}>
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
          <input type="hidden" name={@form[:media_source_id].name} value={@media_source.id} />

          <p class="text-sm text-text-muted">
            {dgettext(
              "admin_media_imports",
              "We process new and changed files, subtitles included, and remove the media of deleted files."
            )}
          </p>

          <label class="flex items-start gap-related">
            <.checkbox
              id="run-import-read-every-file"
              field={@form[:read_every_file_again?]}
              class="mt-0.5"
            />
            <.stack space="tight" class="min-w-0">
              <span class="text-sm font-semibold text-text">
                {dgettext("admin_media_imports", "Read every file again")}
              </span>
              <span class="text-xs text-text-muted">
                {dgettext(
                  "admin_media_imports",
                  "Even files that haven't changed. Each file is matched again, but manual matches are kept."
                )}
              </span>
            </.stack>
          </label>

          <label
            :if={@media_source.media_type in [:movie, :tv_show_episode, :sports_event]}
            class="flex items-start gap-related"
          >
            <.checkbox
              id="run-import-regenerate"
              field={@form[:regenerate_thumbnails_and_markers?]}
              class="mt-0.5"
            />
            <.stack space="tight" class="min-w-0">
              <span class="text-sm font-semibold text-text">
                {dgettext("admin_media_imports", "Regenerate thumbnails and markers")}
              </span>
              <span class="text-xs text-text-muted">
                {dgettext(
                  "admin_media_imports",
                  "For every video, even unchanged ones. New files always get them."
                )}
              </span>
            </.stack>
          </label>

          <.field_errors field={@form[:media_source_id]} show_untouched />

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
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("start", %{"run_import" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _media_import} ->
        Flash.send_flash(:info, dgettext("admin_media_imports", "Import started"))
        socket.assigns.on_close.()
        {:noreply, socket}

      # Such as another import of the Media Source, started while the dialog was open
      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("close", _params, socket) do
    socket.assigns.on_close.()
    {:noreply, socket}
  end
end
