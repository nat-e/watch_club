defmodule WatchClubWeb.Admin.MediaSourceHistoryPage do
  @moduledoc """
  Instance-administrator page that shows the `Media Import` history for one
  `Media Source` and exposes the Run import flow.

  Lives at `/admin/media/sources/:id/history`. Sibling of `MediaSourcesPage`.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Admin.MediaSources.HistoryHeader
  import WatchClubWeb.Admin.MediaSources.MediaImportHistoryTable
  import WatchClubWeb.Admin.MediaSources.RunImportModal

  alias Phoenix.PubSub
  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.Source

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

    case MediaSources.get_media_source_by_id(id,
           actor: socket.assigns.current_user,
           load: [:imports]
         ) do
      {:ok, media_source} ->
        {:noreply, assign(socket, :media_source, media_source)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, dgettext("admin_media_imports", "Media Source not found"))
         |> push_navigate(to: ~p"/admin/media/sources")}
    end
  end

  @impl true
  def render(%{media_source: %Source{}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      space="section"
      class="max-w-panel"
    >
      <.history_header media_source={@media_source} />

      <.section title={dgettext("admin_media_imports", "Import history")}>
        <.empty :if={@media_source.imports == []} border={false}>
          <:icon><Lucideicons.history /></:icon>
          <:title>{dgettext("admin_media_imports", "No Media Imports yet")}</:title>
          <:description>
            {dgettext(
              "admin_media_imports",
              "This Media Source has not been imported yet. Run an import to add your medias."
            )}
          </:description>
          <.button
            id="empty-history-run-import-button"
            variant="primary"
            phx-click="open_run_import_modal"
            phx-value-id={@media_source.id}
          >
            <:icon position="start"><Lucideicons.play /></:icon>
            {dgettext("admin_media_imports", "Run import")}
          </.button>
        </.empty>

        <.media_import_history_table
          :if={@media_source.imports != []}
          imports={@media_source.imports}
          locale={@current_user.settings.locale}
        />
      </.section>

      <.run_import_modal :if={@run_modal_open?} media_source={@media_source} />
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
    %{"media_source_id" => id} = params
    refresh_metadata? = params["refresh_metadata"] == "true"

    case MediaSources.start_media_import(id, %{refresh_metadata?: refresh_metadata?},
           actor: socket.assigns.current_user
         ) do
      {:ok, _media_import} ->
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

  def handle_event("cancel_media_import", %{"id" => media_import_id}, socket) do
    actor = socket.assigns.current_user

    with {:ok, media_import} <- MediaSources.get_media_import_by_id(media_import_id, actor: actor),
         {:ok, _media_import} <- MediaSources.cancel_media_import(media_import, actor: actor) do
      {:noreply, put_flash(socket, :info, dgettext("admin_media_imports", "Import cancelled"))}
    else
      {:error, _error} ->
        {:noreply,
         put_flash(socket, :error, dgettext("admin_media_imports", "Could not cancel import"))}
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "media_sources:" <> _,
          payload: %Ash.Notifier.Notification{action: %{name: :destroy}}
        },
        socket
      ) do
    {:noreply,
     socket
     |> put_flash(:info, dgettext("admin_media_imports", "Media Source was deleted"))
     |> push_navigate(to: ~p"/admin/media/sources")}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "media_sources:" <> _}, socket) do
    {:noreply, reload_media_source(socket)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "media_imports:" <> _}, socket) do
    {:noreply, reload_media_source(socket)}
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
        PubSub.unsubscribe(WatchClub.PubSub, "media_sources")
        PubSub.unsubscribe(WatchClub.PubSub, "media_imports:#{old}")
      end

      PubSub.subscribe(WatchClub.PubSub, "media_sources")
      PubSub.subscribe(WatchClub.PubSub, "media_imports:#{id}")
    end

    assign(socket, :subscribed_id, id)
  end

  defp reload_media_source(%{assigns: %{media_source: %Source{id: id}}} = socket) do
    case MediaSources.get_media_source_by_id(id,
           actor: socket.assigns.current_user,
           load: [:imports]
         ) do
      {:ok, media_source} -> assign(socket, :media_source, media_source)
      {:error, _} -> socket
    end
  end
end
