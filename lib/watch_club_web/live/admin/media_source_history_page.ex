defmodule WatchClubWeb.Admin.MediaSourceHistoryPage do
  @moduledoc """
  Instance-administrator page that shows the `Media Import` history for one
  `Media Source` and exposes the Run import flow.

  Lives at `/admin/media/sources/:id/history`. Sibling of `MediaSourcesPage`.
  """
  use WatchClubWeb, :live_view

  # The fields that need to be loaded on the Source object to display the page
  @media_source_fields [:imports]

  import WatchClubWeb.Admin.MediaSources.{HistoryHeader, MediaImportHistoryTable}

  alias WatchClubWeb.Admin.MediaSources.RunImportModalLive

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> WatchClub.PubSub.subscribe_if_connected("media_sources:admin")
     |> assign(:run_modal_open?, false)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case MediaSources.get_media_source_by_id(id,
           actor: socket.assigns.current_user,
           load: @media_source_fields
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
      instance_settings={@instance_settings}
      playback_session={@playback_session}
      space="section"
      class="max-w-panel"
      title={@media_source.name}
    >
      <:parent
        navigate={~p"/admin/media/sources"}
        label={dgettext("admin_media_imports", "Media Sources")}
      />
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

      <.live_component
        :if={@run_modal_open?}
        module={RunImportModalLive}
        id="run-import"
        media_source={@media_source}
        current_user={@current_user}
      />
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      playback_session={@playback_session}
      title={dgettext("admin_media_imports", "Media Sources")}
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

  def handle_event("close_modals", _params, socket) do
    {:noreply, assign(socket, :run_modal_open?, false)}
  end

  def handle_event("cancel_media_import", %{"id" => media_import_id}, socket) do
    actor = socket.assigns.current_user

    media_import = MediaSources.get_media_import_by_id!(media_import_id, actor: actor)
    MediaSources.cancel_media_import!(media_import, actor: actor)

    {:noreply, put_flash(socket, :info, dgettext("admin_media_imports", "Import cancelled"))}
  end

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info(:media_import_started, socket) do
    {:noreply,
     socket
     |> assign(:run_modal_open?, false)
     |> put_flash(:info, dgettext("admin_media_imports", "Import started"))}
  end

  # The source was deleted, navigate back to the list page
  def handle_info(%Notification{data: %Source{id: source_id}, action: %{name: :destroy}}, socket)
      when source_id == socket.assigns.media_source.id do
    {:noreply,
     socket
     |> put_flash(:info, dgettext("admin_media_imports", "Media Source was deleted"))
     |> push_navigate(to: ~p"/admin/media/sources")}
  end

  # The source has changed, reload the page
  def handle_info(%Notification{data: %Source{id: source_id}}, socket)
      when source_id == socket.assigns.media_source.id do
    {:noreply, socket |> reload_media_source()}
  end

  # An import related to this source has changed, reload the page
  def handle_info(%Notification{data: %Import{media_source_id: source_id}}, socket)
      when source_id == socket.assigns.media_source.id do
    {:noreply, socket |> reload_media_source()}
  end

  # Ignore all other messages
  def handle_info(_message, socket), do: {:noreply, socket}

  defp reload_media_source(socket) do
    source =
      MediaSources.get_media_source_by_id!(socket.assigns.media_source.id,
        load: @media_source_fields,
        actor: socket.assigns.current_user
      )

    socket |> assign(media_source: source)
  end
end
