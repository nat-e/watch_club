defmodule WatchClubWeb.Clubs.SettingsPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Clubs.Settings.{
    CreateOrEditLibraryModal,
    DeleteLibraryModal,
    LibraryList
  }

  alias WatchClubWeb.Components.UI.IconPickerLive

  on_mount {WatchClubWeb.Hooks.LoadClub, true}

  @impl true
  def render(%{club: %Club{}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      space="section"
      class="max-w-panel"
      title={dgettext("clubs", "Club Settings")}
    >
      <:parent navigate={~p"/clubs/#{@club.id}"} label={@club.name}>
        <.avatar id={@club.id} name={@club.name} size="xs" aria-hidden="true" />
      </:parent>
      <.page_description text={
        dgettext("clubs", "Manage %{club_name}'s profile and libraries.", club_name: @club.name)
      } />

      <.section
        title={dgettext("clubs", "General")}
        description={dgettext("clubs", "Update the basic club information.")}
      >
        <.form
          for={@form}
          id="update_club_form"
          class="w-full sm:max-w-sm"
          phx-change="validate_update_club"
          phx-submit="submit_update_club"
          phx-mounted={JS.focus_first()}
        >
          <.field
            field={@form[:name]}
            label={dgettext("clubs", "Club Name")}
            type="text"
          />
          <:action class="sm:justify-start">
            <.button id="club-settings-submit-button" type="submit" class="w-fit">
              {dgettext("clubs", "Edit Club")}
            </.button>
          </:action>
        </.form>
      </.section>

      <.section
        title={dgettext("clubs", "Libraries")}
        description={
          dgettext(
            "clubs",
            "Create, edit, delete, and reorder club libraries. Each library contains one content type."
          )
        }
      >
        <:action>
          <.button
            id="open-create-library-modal-button"
            phx-click="open_create_library_modal"
          >
            <Lucideicons.plus />
            {dgettext("clubs", "Create library")}
          </.button>
        </:action>

        <.library_list libraries={@libraries} />
      </.section>

      <.create_or_edit_library_modal
        :if={@library_form}
        form={@library_form}
        content_types={ContentType.library_display_order()}
      />
      <.live_component
        :if={@library_to_update_icon}
        module={IconPickerLive}
        id={"library-icon-picker-#{@library_to_update_icon.id}"}
        selected_icon={@library_to_update_icon.icon}
        title={dgettext("clubs", "Change icon")}
        description={
          raw(
            dgettext("clubs", "Select a new icon for the %{library_name} library",
              library_name: gtbold(@library_to_update_icon.name)
            )
          )
        }
        on_select={JS.push("library_icon_selected")}
        on_close={JS.push("close_modals")}
      />
      <.delete_library_modal :if={@library_to_delete} library={@library_to_delete} />
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(%{"club_id" => club_id}, _uri, socket) do
    WatchClub.PubSub.subscribe_if_connected(socket, "club:#{club_id}")
    form = Clubs.form_to_update_club(socket.assigns.club, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> close_modals()
     |> reload_libraries!()
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_info(%Notification{resource: Club}, socket) do
    {:noreply, socket |> reload_club()}
  end

  def handle_info(%Notification{resource: Library}, socket) do
    {:noreply, socket |> reload_libraries!()}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate_update_club", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit_update_club", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, updated_club} ->
        {:noreply, assign(socket, :club, updated_club)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  def handle_event("open_create_library_modal", _params, socket) do
    form =
      Clubs.form_to_create_library(
        actor: socket.assigns.current_user,
        prepare_params: fn params, _ ->
          Map.put(params, :club_id, socket.assigns.club.id)
        end
      )

    {:noreply, socket |> assign(:library_form, to_form(form))}
  end

  def handle_event("open_edit_library_modal", %{"library_id" => library_id}, socket) do
    form =
      get_library_by_id(socket, library_id)
      |> Clubs.form_to_update_library(actor: socket.assigns.current_user)

    {:noreply, socket |> assign(library_form: to_form(form))}
  end

  def handle_event("validate_library_form", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.library_form, params)
    {:noreply, socket |> assign(:library_form, form)}
  end

  def handle_event("submit_library_form", %{"form" => params}, socket) do
    form = socket.assigns.library_form
    edit? = form.source.type == :update

    case AshPhoenix.Form.submit(form, params: params, read_one?: true) do
      {:ok, _library} ->
        {:noreply,
         socket
         |> close_modals()
         |> put_flash(
           :success,
           (edit? && dgettext("clubs", "Library updated")) || dgettext("clubs", "Library created")
         )}

      {:error, form} ->
        {:noreply, socket |> assign(:library_form, form)}
    end
  end

  def handle_event("reorder_libraries", %{"ids" => ordered_ids}, socket) do
    Clubs.reorder_libraries!(socket.assigns.club, ordered_ids, actor: socket.assigns.current_user)

    {:noreply, socket}
  end

  def handle_event("open_icon_picker", %{"library_id" => library_id}, socket) do
    {:noreply, socket |> assign(:library_to_update_icon, get_library_by_id(socket, library_id))}
  end

  def handle_event("library_icon_selected", %{"icon" => icon}, socket) do
    socket.assigns.library_to_update_icon
    |> Clubs.update_library!(%{icon: icon}, actor: socket.assigns.current_user)

    {:noreply, socket |> close_modals()}
  end

  def handle_event("open_delete_library_modal", %{"library_id" => library_id}, socket) do
    {:noreply, socket |> assign(:library_to_delete, get_library_by_id(socket, library_id))}
  end

  def handle_event("confirm_delete_library", _params, socket) do
    Clubs.destroy_library!(socket.assigns.library_to_delete, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> close_modals()
     |> put_flash(:success, dgettext("clubs", "Library deleted"))}
  end

  def handle_event("close_modals", _params, socket) do
    {:noreply, socket |> close_modals()}
  end

  defp reload_club(socket) do
    # We need to handle error case since Ash.NotFound is expected when PubSub is triggered by Club deletion
    case Clubs.get_club_by_id(socket.assigns.club.id, actor: socket.assigns.current_user) do
      {:ok, club} -> socket |> assign(:club, club)
      {:error, _error} -> socket |> redirect_home()
    end
  end

  defp redirect_home(socket) do
    socket
    |> put_flash(:error, dgettext("clubs", "The club you were looking for does not exist"))
    |> push_navigate(to: ~p"/")
  end

  defp reload_libraries!(socket) do
    libraries =
      Clubs.list_club_libraries!(socket.assigns.club.id, actor: socket.assigns.current_user)

    socket |> assign(:libraries, libraries)
  end

  defp close_modals(socket) do
    socket
    |> assign(:library_form, nil)
    |> assign(:library_to_update_icon, nil)
    |> assign(:library_to_delete, nil)
  end

  defp get_library_by_id(socket, library_id),
    do: Enum.find(socket.assigns.libraries, &(&1.id == library_id))
end
