defmodule WatchClubWeb.Admin.MediaSourcesPage do
  @moduledoc """
  Instance-administrator page that lists every `Media Source` on the
  instance and lets the admin add, edit, delete, and trigger imports.

  Lives at `/admin/media/sources`. Sources are grouped by `MediaSourceType`
  (Filesystem, Radarr, and Sonarr), each section with its own primary "Add"
  action that drives the type-specific create flow. The history of one
  Media Source is on the sibling `MediaSourceHistoryPage`.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Admin.MediaSources.CreateOrEditMediaSourceModal
  import WatchClubWeb.Admin.MediaSources.DeleteMediaSourceModal
  import WatchClubWeb.Admin.MediaSources.MediaSourceCard
  import WatchClubWeb.Admin.MediaSources.RunImportModal
  import WatchClubWeb.Components.Media.SourceTypeIcon
  import WatchClubWeb.Components.Settings.SettingsHeader

  alias Phoenix.PubSub
  alias WatchClub.Media
  alias WatchClub.Media.{FilesystemMediaSource, MediaImport, MediaSource, ServarrMediaSource}
  alias WatchClubWeb.Admin.MediaSources.AddServarrSourceModal

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
    groups = Enum.group_by(assigns.media_sources, & &1.source_type)

    assigns =
      assigns
      |> assign(:filesystem_sources, Map.get(groups, :filesystem, []))
      |> assign(:radarr_sources, Map.get(groups, :radarr, []))
      |> assign(:sonarr_sources, Map.get(groups, :sonarr, []))

    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      space="cluster"
      class="max-w-panel"
    >
      <.settings_header
        title={dgettext("admin_media_imports", "Media Sources")}
        description={
          dgettext(
            "admin_media_imports",
            "Configure Media Sources to import and request media to your Watch Club instance."
          )
        }
      />

      <.stack space="group">
        <.source_type_section
          type={:filesystem}
          title={dgettext("admin_media_imports", "Filesystem")}
          description={
            dgettext(
              "admin_media_imports",
              "Import media from a directory on your hard drive or a remote filesystem."
            )
          }
          add_event="open_create_filesystem_source_modal"
          sources={@filesystem_sources}
          empty_copy={
            dgettext(
              "admin_media_imports",
              "Configure a Filesystem source to scan a directory for media."
            )
          }
          locale={@current_user.settings.locale}
        />

        <.source_type_section
          type={:radarr}
          title={dgettext("admin_media_imports", "Radarr")}
          description={dgettext("admin_media_imports", "Import movies from a Radarr server.")}
          add_event="open_add_radarr_source_modal"
          sources={@radarr_sources}
          empty_copy={
            dgettext(
              "admin_media_imports",
              "Connect a Radarr server to import movies and fulfill movie requests."
            )
          }
          locale={@current_user.settings.locale}
        />

        <.source_type_section
          type={:sonarr}
          title={dgettext("admin_media_imports", "Sonarr")}
          description={dgettext("admin_media_imports", "Import TV shows from a Sonarr server.")}
          add_event="open_add_sonarr_source_modal"
          sources={@sonarr_sources}
          empty_copy={
            dgettext(
              "admin_media_imports",
              "Connect a Sonarr server to import TV shows and fulfill TV show requests."
            )
          }
          locale={@current_user.settings.locale}
        />
      </.stack>

      <.create_or_edit_media_source_modal
        :if={@configure_form}
        mode={@configure_mode}
        form={@configure_form}
        media_source={@configure_media_source}
      />
      <.live_component
        :if={@servarr_modal}
        module={AddServarrSourceModal}
        id={@servarr_modal.id}
        mode={@servarr_modal.mode}
        flavor={@servarr_modal.flavor}
        media_source={@servarr_modal.media_source}
        current_user={@current_user}
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

  attr :type, :atom, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :add_event, :string, required: true
  attr :sources, :list, required: true
  attr :empty_copy, :string, required: true
  attr :locale, :atom, required: true

  defp source_type_section(assigns) do
    ~H"""
    <.card as="section" data_slot="section" padding="cluster" class="grid gap-group">
      <div class="flex flex-col items-start gap-related sm:flex-row sm:items-start sm:justify-between">
        <div class="flex min-w-0 items-start gap-related">
          <.source_type_icon type={@type} size="header" />
          <.stack space="tight" class="min-w-0">
            <h2 class="text-xl font-heading font-semibold tracking-tight text-text">
              {@title}
            </h2>
            <p class="max-w-readable text-sm leading-6 text-text-muted">
              {@description}
            </p>
          </.stack>
        </div>

        <.button
          id={"add-#{@type}-source"}
          variant="primary"
          phx-click={@add_event}
        >
          <:icon position="start"><Lucideicons.plus /></:icon>
          {dgettext("admin_media_imports", "Add %{title} source", title: @title)}
        </.button>
      </div>

      <.empty :if={@sources == []} border={false}>
        <:icon><.source_type_icon type={@type} size="empty" /></:icon>
        <:title>
          {dgettext("admin_media_imports", "No %{title} sources yet", title: @title)}
        </:title>
        <:description>
          {@empty_copy}
        </:description>
      </.empty>

      <ul :if={@sources != []} class="grid list-none gap-related p-0">
        <li :for={source <- @sources}>
          <.media_source_card media_source={source} locale={@locale} />
        </li>
      </ul>
    </.card>
    """
  end

  # ---------------------------------------------------------------------------
  # Filesystem source modal (create + edit)
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("open_create_filesystem_source_modal", _params, socket) do
    form =
      Media.form_to_create_filesystem_media_source(actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> reset_modals()
     |> assign(:configure_mode, :create)
     |> assign(:configure_form, to_form(form))
     |> assign(:configure_media_source, nil)}
  end

  def handle_event("open_edit_media_source_modal", %{"id" => id}, socket) do
    case find_media_source(socket, id) do
      %MediaSource{source_type: :filesystem} = media_source ->
        form =
          to_form(
            %{"filesystem_path" => media_source.implementation.filesystem_path},
            as: :form
          )

        {:noreply,
         socket
         |> reset_modals()
         |> assign(:configure_mode, :edit)
         |> assign(:configure_form, form)
         |> assign(:configure_media_source, media_source)}

      %MediaSource{source_type: source_type} = media_source
      when source_type in [:radarr, :sonarr] ->
        {:noreply,
         socket
         |> reset_modals()
         |> assign(:servarr_modal, %{
           id: servarr_modal_id(),
           mode: :edit,
           flavor: source_type,
           media_source: media_source
         })}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("validate_configure_media_source", %{"form" => params}, socket) do
    form =
      case socket.assigns.configure_mode do
        :create -> AshPhoenix.Form.validate(socket.assigns.configure_form, params)
        :edit -> to_form(params, as: :form)
      end

    {:noreply, assign(socket, :configure_form, form)}
  end

  def handle_event("submit_configure_media_source", %{"form" => params}, socket) do
    case socket.assigns.configure_mode do
      :create -> submit_create_filesystem(socket, params)
      :edit -> submit_edit_filesystem(socket, params)
    end
  end

  # ---------------------------------------------------------------------------
  # Servarr (Radarr / Sonarr) source modal
  # ---------------------------------------------------------------------------

  def handle_event("open_add_radarr_source_modal", _params, socket) do
    {:noreply, open_servarr_create_modal(socket, :radarr)}
  end

  def handle_event("open_add_sonarr_source_modal", _params, socket) do
    {:noreply, open_servarr_create_modal(socket, :sonarr)}
  end

  # ---------------------------------------------------------------------------
  # Delete / run-import modals
  # ---------------------------------------------------------------------------

  def handle_event("open_delete_modal", %{"id" => id}, socket) do
    case find_media_source(socket, id) do
      %MediaSource{} = media_source ->
        {:noreply, socket |> reset_modals() |> assign(:delete_media_source, media_source)}

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
        {:noreply, socket |> reset_modals() |> assign(:run_import_media_source, media_source)}

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
  def handle_info(:close_servarr_source_modal, socket) do
    {:noreply, assign(socket, :servarr_modal, nil)}
  end

  def handle_info({:servarr_source_saved, mode}, socket) do
    message =
      case mode do
        :edit -> dgettext("admin_media_imports", "Media Source updated")
        :create -> dgettext("admin_media_imports", "Media Source configured")
      end

    {:noreply,
     socket
     |> assign(:servarr_modal, nil)
     |> put_flash(:info, message)}
  end

  def handle_info(:servarr_source_save_failed, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       dgettext("admin_media_imports", "Could not save source")
     )}
  end

  def handle_info(%Ash.Notifier.Notification{resource: resource}, socket)
      when resource in [MediaSource, FilesystemMediaSource, ServarrMediaSource, MediaImport] do
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
        load: [:latest_import, :implementation]
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
    |> assign(:servarr_modal, nil)
    |> assign(:delete_media_source, nil)
    |> assign(:run_import_media_source, nil)
  end

  defp submit_create_filesystem(socket, params) do
    case AshPhoenix.Form.submit(socket.assigns.configure_form, params: params) do
      {:ok, _media_source} ->
        {:noreply,
         socket
         |> reset_modals()
         |> put_flash(:info, dgettext("admin_media_imports", "Media Source configured"))}

      {:error, form} ->
        {:noreply, assign(socket, :configure_form, form)}
    end
  end

  defp submit_edit_filesystem(socket, params) do
    media_source = socket.assigns.configure_media_source

    case Media.update_filesystem_media_source(
           media_source.implementation,
           %{filesystem_path: params["filesystem_path"]},
           actor: socket.assigns.current_user
         ) do
      {:ok, _impl} ->
        {:noreply,
         socket
         |> reset_modals()
         |> put_flash(:info, dgettext("admin_media_imports", "Media Source updated"))}

      {:error, _error} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext("admin_media_imports", "Could not update Media Source")
         )}
    end
  end

  defp open_servarr_create_modal(socket, flavor) do
    socket
    |> reset_modals()
    |> assign(:servarr_modal, %{
      id: servarr_modal_id(),
      mode: :create,
      flavor: flavor,
      media_source: nil
    })
  end

  defp servarr_modal_id do
    "servarr-source-modal-#{System.unique_integer([:positive, :monotonic])}"
  end
end
