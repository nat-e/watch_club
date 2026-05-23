defmodule WatchClubWeb.Admin.MediaImportHistoryPage do
  @moduledoc """
  Instance-administrator page that shows the run history for one
  `Media Import Configuration` and exposes the Run import flow.

  Lives at `/admin/media/imports/:id/history`. Sibling of
  `MediaImportsPage`.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Admin.MediaImports.HistoryHeader
  import WatchClubWeb.Admin.MediaImports.HistoryTable
  import WatchClubWeb.Admin.MediaImports.RunImportModal

  alias Phoenix.PubSub
  alias WatchClub.Media
  alias WatchClub.Media.{ImportConfiguration, ImportRun}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:run_modal_open?, false)
     |> assign(:subscribed_id, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    # Subscribe before load to avoid race condition
    socket = resubscribe(socket, id)

    case Media.get_import_configuration_by_id(id,
           actor: socket.assigns.current_user,
           load: [:imports]
         ) do
      {:ok, configuration} ->
        {:noreply, assign(socket, :configuration, configuration)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, dgettext("admin_media_imports", "Import configuration not found"))
         |> push_navigate(to: ~p"/admin/media/imports")}
    end
  end

  @impl true
  def render(%{configuration: %ImportConfiguration{}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      space="section"
      class="max-w-panel"
    >
      <.history_header configuration={@configuration} />

      <.section title={dgettext("admin_media_imports", "Import history")}>
        <.empty :if={@configuration.imports == []} border={false}>
          <:icon><Lucideicons.history /></:icon>
          <:title>{dgettext("admin_media_imports", "No runs yet")}</:title>
          <:description>
            {dgettext(
              "admin_media_imports",
              "This import has not ran yet. Run it to import your medias."
            )}
          </:description>
          <.button
            id="empty-history-run-import-button"
            variant="primary"
            phx-click="open_run_import_modal"
            phx-value-id={@configuration.id}
          >
            <:icon position="start"><Lucideicons.play /></:icon>
            {dgettext("admin_media_imports", "Run import")}
          </.button>
        </.empty>

        <.history_table
          :if={@configuration.imports != []}
          runs={@configuration.imports}
          locale={@current_user.settings.locale}
        />
      </.section>

      <.run_import_modal :if={@run_modal_open?} configuration={@configuration} />
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
    >
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Modals
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("open_run_import_modal", _params, socket) do
    {:noreply, assign(socket, :run_modal_open?, true)}
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
         |> assign(:run_modal_open?, false)
         |> put_flash(:info, dgettext("admin_media_imports", "Import started"))}

      {:error, _error} ->
        {:noreply,
         socket
         |> assign(:run_modal_open?, false)
         |> put_flash(:error, dgettext("admin_media_imports", "Could not start import"))}
    end
  end

  def handle_event("close_modals", _params, socket) do
    {:noreply, assign(socket, :run_modal_open?, false)}
  end

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info(
        %Ash.Notifier.Notification{resource: ImportConfiguration, action: %{name: :destroy}},
        socket
      ) do
    {:noreply,
     socket
     |> put_flash(:info, dgettext("admin_media_imports", "Configuration was deleted"))
     |> push_navigate(to: ~p"/admin/media/imports")}
  end

  def handle_info(%Ash.Notifier.Notification{resource: resource}, socket)
      when resource in [ImportConfiguration, ImportRun] do
    {:noreply, reload_configuration(socket)}
  end

  # Catch all clause to avoid crash if we publish more messages on this topic later
  def handle_info(_message, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp resubscribe(socket, id) when socket.assigns.subscribed_id == id, do: socket

  defp resubscribe(socket, id) do
    if connected?(socket) do
      if old = socket.assigns.subscribed_id do
        PubSub.unsubscribe(WatchClub.PubSub, "media_imports:#{old}")
      end

      PubSub.subscribe(WatchClub.PubSub, "media_imports:#{id}")
    end

    assign(socket, :subscribed_id, id)
  end

  defp reload_configuration(%{assigns: %{configuration: %ImportConfiguration{id: id}}} = socket) do
    case Media.get_import_configuration_by_id(id,
           actor: socket.assigns.current_user,
           load: [:imports]
         ) do
      {:ok, configuration} -> assign(socket, :configuration, configuration)
      {:error, _} -> socket
    end
  end
end
