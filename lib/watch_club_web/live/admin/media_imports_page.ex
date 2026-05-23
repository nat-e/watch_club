defmodule WatchClubWeb.Admin.MediaImportsPage do
  @moduledoc """
  Instance-administrator page that lists every `Media Import Configuration`
  on the instance and lets the admin create, edit (path only), enable/disable,
  delete, and trigger imports.

  Lives at `/admin/media/imports`. The history of one configuration is on the
  sibling `MediaImportHistoryPage`.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Admin.MediaImports.ConfigurationCard
  import WatchClubWeb.Admin.MediaImports.CreateOrEditImportModal
  import WatchClubWeb.Admin.MediaImports.DeleteConfigurationModal
  import WatchClubWeb.Admin.MediaImports.RunImportModal
  import WatchClubWeb.Components.Settings.SettingsHeader

  alias Phoenix.PubSub
  alias WatchClub.Media
  alias WatchClub.Media.{ImportConfiguration, ImportRun}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(WatchClub.PubSub, "media_imports")
    end

    {:ok,
     socket
     |> reset_modals()
     |> load_configurations()}
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
        title={dgettext("admin_media_imports", "Media Imports")}
        description={
          dgettext("admin_media_imports", "Manage how media is imported into this instance.")
        }
      />

      <.section
        title={dgettext("admin_media_imports", "Configured imports")}
        description={
          dgettext(
            "admin_media_imports",
            "Each import scans one directory for one type of media."
          )
        }
      >
        <:action>
          <.button
            id="configure-new-import-button"
            variant="primary"
            phx-click="open_create_import_modal"
          >
            <:icon position="start"><Lucideicons.plus /></:icon>
            {dgettext("admin_media_imports", "Configure new import")}
          </.button>
        </:action>

        <.empty :if={@configurations == []} border={false}>
          <:icon><Lucideicons.folder_plus /></:icon>
          <:title>{dgettext("admin_media_imports", "No imports configured yet")}</:title>
          <:description>
            {dgettext(
              "admin_media_imports",
              "Configure an import to add medias to your Watch Club instance."
            )}
          </:description>
        </.empty>

        <ul :if={@configurations != []} class="grid list-none gap-related p-0">
          <li :for={configuration <- @configurations}>
            <.configuration_card
              configuration={configuration}
              locale={@current_user.settings.locale}
            />
          </li>
        </ul>
      </.section>

      <.create_or_edit_import_modal
        :if={@configure_form}
        mode={@configure_mode}
        form={@configure_form}
        configuration={@configure_configuration}
      />
      <.delete_configuration_modal
        :if={@delete_configuration}
        configuration={@delete_configuration}
      />
      <.run_import_modal
        :if={@run_import_configuration}
        configuration={@run_import_configuration}
      />
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Modal open/close
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("open_create_import_modal", _params, socket) do
    form =
      Media.form_to_create_filesystem_import_configuration(actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:configure_mode, :create)
     |> assign(:configure_form, to_form(form))
     |> assign(:configure_configuration, nil)}
  end

  def handle_event("open_edit_import_modal", %{"id" => id}, socket) do
    case find_configuration(socket, id) do
      %ImportConfiguration{} = configuration ->
        form =
          Media.form_to_update_import_configuration(configuration,
            actor: socket.assigns.current_user
          )

        {:noreply,
         socket
         |> assign(:configure_mode, :edit)
         |> assign(:configure_form, to_form(form))
         |> assign(:configure_configuration, configuration)}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("validate_configure_import", %{"form" => params}, socket) do
    {:noreply,
     assign(socket, :configure_form, AshPhoenix.Form.validate(socket.assigns.configure_form, params))}
  end

  def handle_event("submit_configure_import", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.configure_form, params: params) do
      {:ok, _configuration} ->
        flash_message =
          case socket.assigns.configure_mode do
            :create -> dgettext("admin_media_imports", "Import configured")
            :edit -> dgettext("admin_media_imports", "Import updated")
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
    case find_configuration(socket, id) do
      %ImportConfiguration{} = configuration ->
        {:noreply, assign(socket, :delete_configuration, configuration)}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("confirm_delete_configuration", %{"id" => id}, socket) do
    case find_configuration(socket, id) do
      %ImportConfiguration{} = configuration ->
        case Media.destroy_import_configuration(configuration, actor: socket.assigns.current_user) do
          :ok ->
            {:noreply,
             socket
             |> reset_modals()
             |> put_flash(:info, dgettext("admin_media_imports", "Import configuration deleted"))}

          {:error, _error} ->
            {:noreply,
             socket
             |> reset_modals()
             |> put_flash(
               :error,
               dgettext("admin_media_imports", "Could not delete import configuration")
             )}
        end

      nil ->
        {:noreply, reset_modals(socket)}
    end
  end

  def handle_event("open_run_import_modal", %{"id" => id}, socket) do
    case find_configuration(socket, id) do
      %ImportConfiguration{} = configuration ->
        {:noreply, assign(socket, :run_import_configuration, configuration)}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("confirm_run_import", %{"run_import" => params}, socket) do
    %{"configuration_id" => id} = params
    refresh_metadata? = params["refresh_metadata"] == "true"

    case Media.start_import_run(id, %{refresh_metadata?: refresh_metadata?},
           actor: socket.assigns.current_user
         ) do
      {:ok, _run} ->
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
      when resource in [ImportConfiguration, ImportRun] do
    {:noreply, load_configurations(socket)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp load_configurations(socket) do
    configurations =
      Media.list_import_configurations!(
        actor: socket.assigns.current_user,
        load: [:latest_run, :name]
      )

    assign(socket, :configurations, configurations)
  end

  defp find_configuration(socket, id) do
    Enum.find(socket.assigns.configurations, &(&1.id == id))
  end

  defp reset_modals(socket) do
    socket
    |> assign(:configure_mode, nil)
    |> assign(:configure_form, nil)
    |> assign(:configure_configuration, nil)
    |> assign(:delete_configuration, nil)
    |> assign(:run_import_configuration, nil)
  end
end
