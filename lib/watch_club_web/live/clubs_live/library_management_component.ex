defmodule WatchClubWeb.ClubsLive.LibraryManagementComponent do
  @moduledoc """
  Stateful library management section for a club settings page.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.ClubsLive.LibraryManagementComponents

  alias WatchClubWeb.Hooks.Flash

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="contents">
      <.settings_section
        title={dgettext("clubs", "Libraries")}
        description={
          dgettext(
            "clubs",
            "Create, rename, delete, and reorder club libraries. Multiple libraries can use the same content type."
          )
        }
      >
        <:action>
          <.button phx-click="open_create_library_modal" phx-target={@myself}>
            <Lucideicons.plus />
            {dgettext("clubs", "Create library")}
          </.button>
        </:action>

        <.libraries_empty_state :if={@libraries == []} target={@myself} />
        <.library_list :if={@libraries != []} libraries={@libraries} target={@myself} />
      </.settings_section>

      <.create_library_modal
        :if={@create_library_form}
        form={@create_library_form}
        content_types={ContentType.values()}
        target={@myself}
      />
      <.delete_library_modal
        :if={@library_to_delete}
        library={@library_to_delete}
        target={@myself}
      />
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       libraries: [],
       create_library_form: nil,
       library_to_delete: nil,
       loaded_club_id: nil
     )}
  end

  @impl true
  def update(%{club: %Club{} = club, current_user: current_user} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> load_libraries_if_needed(club.id, current_user)

    {:ok, socket}
  end

  @impl true
  def handle_event("open_create_library_modal", _params, socket) do
    {:noreply, assign(socket, :create_library_form, create_library_form(socket))}
  end

  def handle_event("validate_create_library", %{"form" => params}, socket) do
    {:noreply,
     assign(
       socket,
       :create_library_form,
       AshPhoenix.Form.validate(socket.assigns.create_library_form, params)
     )}
  end

  def handle_event("submit_create_library", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.create_library_form,
           params: params,
           actor: socket.assigns.current_user
         ) do
      {:ok, _library} ->
        Flash.send_flash(:success, dgettext("clubs", "Library created"))

        {:noreply,
         socket
         |> assign(:create_library_form, nil)
         |> reload_libraries()}

      {:error, form} ->
        {:noreply, assign(socket, :create_library_form, form)}
    end
  end

  def handle_event("rename_library", %{"library_id" => library_id, "value" => name}, socket) do
    socket.assigns.libraries
    |> Enum.find(&(&1.id == library_id))
    |> case do
      %Library{} = library -> rename_library(socket, library, name)
      nil -> {:noreply, socket}
    end
  end

  def handle_event("reorder_libraries", %{"ids" => ordered_ids}, socket) do
    case Clubs.reorder_libraries(socket.assigns.club.id, %{library_ids: ordered_ids},
           actor: socket.assigns.current_user
         ) do
      {:ok, libraries} ->
        {:noreply, assign(socket, :libraries, libraries)}

      {:error, error} ->
        Logger.warning("Error reordering libraries: #{inspect(error)}")
        Flash.send_flash(:error, dgettext("clubs", "Error reordering libraries, try again later"))

        {:noreply, reload_libraries(socket)}
    end
  end

  def handle_event("open_delete_library_modal", %{"library_id" => library_id}, socket) do
    library = Enum.find(socket.assigns.libraries, &(&1.id == library_id))
    {:noreply, assign(socket, :library_to_delete, library)}
  end

  def handle_event("confirm_delete_library", _params, socket) do
    case socket.assigns.library_to_delete do
      %Library{} = library ->
        case Clubs.destroy_library(library, actor: socket.assigns.current_user) do
          :ok ->
            Flash.send_flash(:success, dgettext("clubs", "Library deleted"))

            {:noreply,
             socket
             |> assign(:library_to_delete, nil)
             |> reload_libraries()}

          {:error, error} ->
            Logger.warning("Error deleting library: #{inspect(error)}")
            Flash.send_flash(:error, dgettext("clubs", "Error deleting library, try again later"))

            {:noreply, assign(socket, :library_to_delete, nil)}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("close_modals", _params, socket) do
    {:noreply,
     socket
     |> assign(:create_library_form, nil)
     |> assign(:library_to_delete, nil)}
  end

  defp load_libraries_if_needed(socket, club_id, _current_user)
       when socket.assigns.loaded_club_id == club_id do
    socket
  end

  defp load_libraries_if_needed(socket, club_id, _current_user) do
    socket
    |> assign(:loaded_club_id, club_id)
    |> reload_libraries()
  end

  defp rename_library(socket, library, name) do
    case Clubs.update_library(library, %{name: name}, actor: socket.assigns.current_user) do
      {:ok, %Library{} = library} ->
        {:noreply, assign(socket, :libraries, replace_library(socket.assigns.libraries, library))}

      {:error, error} ->
        Logger.warning("Error renaming library: #{inspect(error)}")
        Flash.send_flash(:error, dgettext("clubs", "Error renaming library, try again later"))

        {:noreply, socket}
    end
  end

  defp reload_libraries(socket) do
    case Clubs.list_club_libraries(socket.assigns.club.id, actor: socket.assigns.current_user) do
      {:ok, libraries} ->
        assign(socket, :libraries, libraries)

      {:error, error} ->
        Logger.warning("Error loading club libraries: #{inspect(error)}")
        Flash.send_flash(:error, dgettext("clubs", "Could not load club libraries"))
        socket
    end
  end

  defp create_library_form(socket) do
    %{
      club: %Club{id: club_id},
      current_user: actor
    } = socket.assigns

    Clubs.form_to_create_library(
      actor: actor,
      params: %{content_type: :movie},
      prepare_params: fn params, _ ->
        Map.put(params, :club_id, club_id)
      end
    )
    |> to_form()
  end

  defp replace_library(libraries, %Library{} = updated_library) do
    Enum.map(libraries, fn
      %Library{id: id} when id == updated_library.id -> updated_library
      library -> library
    end)
  end
end
