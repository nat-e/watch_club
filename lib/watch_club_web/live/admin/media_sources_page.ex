defmodule WatchClubWeb.Admin.MediaSourcesPage do
  @moduledoc """
  Instance-administrator page that lists every `Media Source` on the instance
  and lets the admin create, edit (path only), delete, and trigger Media Imports.

  Lives at `/admin/media/sources`. The Media Import history of one Media Source
  is on the sibling `MediaSourceHistoryPage`.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Admin.MediaSources.CreateOrEditMediaSourceModal
  import WatchClubWeb.Admin.MediaSources.DeleteMediaSourceModal
  import WatchClubWeb.Admin.MediaSources.MediaSourceCard
  import WatchClubWeb.Admin.MediaSources.RunImportModal
  import WatchClubWeb.Components.Settings.SettingsHeader

  alias Phoenix.PubSub
  alias WatchClub.Media
  alias WatchClub.Media.{MediaImport, MediaSource}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(WatchClub.PubSub, "media_sources")
      PubSub.subscribe(WatchClub.PubSub, "media_imports")
    end

    {:ok,
     socket
     |> reset_modals()
     |> load_media_sources()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      space="section"
      class="max-w-panel"
    >
      <.settings_header
        title={dgettext("admin_media_imports", "Media Sources")}
        description={
          dgettext("admin_media_imports", "Manage how media is imported into this instance.")
        }
      />

      <.section
        title={dgettext("admin_media_imports", "Configured sources")}
        description={
          dgettext(
            "admin_media_imports",
            "Each Media Source scans one directory for one type of media."
          )
        }
      >
        <:action>
          <.button
            id="configure-new-media-source-button"
            variant="primary"
            phx-click="open_create_media_source_modal"
          >
            <:icon position="start"><Lucideicons.plus /></:icon>
            {dgettext("admin_media_imports", "Configure new Media Source")}
          </.button>
        </:action>

        <.empty :if={@media_sources == []} border={false}>
          <:icon><Lucideicons.folder_plus /></:icon>
          <:title>{dgettext("admin_media_imports", "No Media Sources configured yet")}</:title>
          <:description>
            {dgettext(
              "admin_media_imports",
              "Configure a Media Source to add medias to your Watch Club instance."
            )}
          </:description>
        </.empty>

        <ul :if={@media_sources != []} class="grid list-none gap-related p-0">
          <li :for={media_source <- @media_sources}>
            <.media_source_card
              media_source={media_source}
              locale={@current_user.settings.locale}
            />
          </li>
        </ul>
      </.section>

      <.create_or_edit_media_source_modal
        :if={@configure_form}
        mode={@configure_mode}
        form={@configure_form}
        media_source={@configure_media_source}
      />
      <.delete_media_source_modal
        :if={@delete_media_source}
        media_source={@delete_media_source}
      />
      <.run_import_modal
        :if={@run_import_media_source}
        media_source={@run_import_media_source}
      />
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Modal open/close
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("open_create_media_source_modal", _params, socket) do
    form =
      Media.form_to_create_filesystem_media_source(actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:configure_mode, :create)
     |> assign(:configure_form, to_form(form))
     |> assign(:configure_media_source, nil)}
  end

  def handle_event("open_edit_media_source_modal", %{"id" => id}, socket) do
    case find_media_source(socket, id) do
      %MediaSource{} = media_source ->
        form =
          Media.form_to_update_media_source(media_source,
            actor: socket.assigns.current_user
          )

        {:noreply,
         socket
         |> assign(:configure_mode, :edit)
         |> assign(:configure_form, to_form(form))
         |> assign(:configure_media_source, media_source)}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("validate_configure_media_source", %{"form" => params}, socket) do
    {:noreply,
     assign(
       socket,
       :configure_form,
       AshPhoenix.Form.validate(socket.assigns.configure_form, params)
     )}
  end

  def handle_event("submit_configure_media_source", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.configure_form, params: params) do
      {:ok, _media_source} ->
        flash_message =
          case socket.assigns.configure_mode do
            :create -> dgettext("admin_media_imports", "Media Source configured")
            :edit -> dgettext("admin_media_imports", "Media Source updated")
          end

        {:noreply,
         socket
         |> reset_modals()
         |> put_flash(:info, flash_message)}

      {:error, form} ->
        {:noreply, assign(socket, :configure_form, form)}
    end
  end

  def handle_event("open_delete_modal", %{"id" => id}, socket) do
    case find_media_source(socket, id) do
      %MediaSource{} = media_source ->
        {:noreply, assign(socket, :delete_media_source, media_source)}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("confirm_delete_media_source", %{"id" => id}, socket) do
    case find_media_source(socket, id) do
      %MediaSource{} = media_source ->
        case Media.destroy_media_source(media_source, actor: socket.assigns.current_user) do
          :ok ->
            {:noreply,
             socket
             |> reset_modals()
             |> put_flash(:info, dgettext("admin_media_imports", "Media Source deleted"))}

          {:error, _error} ->
            {:noreply,
             socket
             |> reset_modals()
             |> put_flash(
               :error,
               dgettext("admin_media_imports", "Could not delete Media Source")
             )}
        end

      nil ->
        {:noreply, reset_modals(socket)}
    end
  end

  def handle_event("open_run_import_modal", %{"id" => id}, socket) do
    case find_media_source(socket, id) do
      %MediaSource{} = media_source ->
        {:noreply, assign(socket, :run_import_media_source, media_source)}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("confirm_run_import", %{"run_import" => params}, socket) do
    %{"media_source_id" => id} = params
    refresh_metadata? = params["refresh_metadata"] == "true"

    case Media.start_media_import(id, %{refresh_metadata?: refresh_metadata?},
           actor: socket.assigns.current_user
         ) do
      {:ok, _media_import} ->
        {:noreply,
         socket
         |> reset_modals()
         |> put_flash(:info, dgettext("admin_media_imports", "Import started"))}

      {:error, _error} ->
        {:noreply,
         socket
         |> reset_modals()
         |> put_flash(:error, dgettext("admin_media_imports", "Could not start import"))}
    end
  end

  def handle_event("close_modals", _params, socket) do
    {:noreply, reset_modals(socket)}
  end

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info(%Ash.Notifier.Notification{resource: resource}, socket)
      when resource in [MediaSource, MediaImport] do
    {:noreply, load_media_sources(socket)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp load_media_sources(socket) do
    media_sources =
      Media.list_media_sources!(
        actor: socket.assigns.current_user,
        load: [:latest_import, :name]
      )

    assign(socket, :media_sources, media_sources)
  end

  defp find_media_source(socket, id) do
    Enum.find(socket.assigns.media_sources, &(&1.id == id))
  end

  defp reset_modals(socket) do
    socket
    |> assign(:configure_mode, nil)
    |> assign(:configure_form, nil)
    |> assign(:configure_media_source, nil)
    |> assign(:delete_media_source, nil)
    |> assign(:run_import_media_source, nil)
  end
end
