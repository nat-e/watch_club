defmodule WatchClubWeb.Clubs.Settings.LibrariesLive do
  @moduledoc """
  Stateful library management section for a club settings page.

  Club libraries are intentionally low-cardinality, and reorder interactions
  work on the complete ordered list, so this component keeps them as a regular
  assign instead of a LiveView stream.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Clubs.Settings.Libraries.CreateOrEditLibraryModal
  import WatchClubWeb.Clubs.Settings.Libraries.DeleteLibraryModal
  import WatchClubWeb.Clubs.Settings.Libraries.LibraryList

  alias WatchClubWeb.Components.UI.IconPickerLive
  alias WatchClubWeb.Hooks.Flash

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="contents">
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
            phx-target={@myself}
          >
            <Lucideicons.plus />
            {dgettext("clubs", "Create library")}
          </.button>
        </:action>

        <.library_list libraries={@libraries} target={@myself} />
      </.section>

      <.create_or_edit_library_modal
        :if={@create_library_form}
        mode={:create}
        form={@create_library_form}
        content_types={ContentType.library_display_order()}
        target={@myself}
      />
      <.create_or_edit_library_modal
        :if={@edit_library_form}
        mode={:edit}
        form={@edit_library_form}
        library={@edit_library}
        content_types={ContentType.library_display_order()}
        target={@myself}
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
        on_select={
          fn icon ->
            Phoenix.LiveView.send_update(@myself,
              selected_library_icon: %{library_id: @library_to_update_icon.id, icon: icon}
            )
          end
        }
        on_close={fn -> Phoenix.LiveView.send_update(@myself, close_icon_picker: true) end}
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
     socket
     |> assign(
       libraries: [],
       create_library_form: nil,
       edit_library: nil,
       edit_library_form: nil,
       library_to_delete: nil,
       library_to_update_icon: nil,
       loaded_club_id: nil
     )}
  end

  @impl true
  def update(%{close_icon_picker: true}, socket) do
    {:ok, assign(socket, :library_to_update_icon, nil)}
  end

  def update(%{selected_library_icon: %{library_id: library_id, icon: icon}}, socket) do
    library = Enum.find(socket.assigns.libraries, &(&1.id == library_id))

    case Clubs.update_library(library, %{icon: icon}, actor: socket.assigns.current_user) do
      {:ok, %Library{} = library} ->
        {:ok,
         socket
         |> assign(:libraries, replace_library(socket.assigns.libraries, library))
         |> assign(:library_to_update_icon, nil)}

      {:error, error} ->
        Logger.warning("Error updating library icon: #{inspect(error)}")

        Flash.send_flash(
          :error,
          dgettext("clubs", "Error updating library icon, try again later")
        )

        {:ok, socket}
    end
  end

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
       AshPhoenix.Form.validate(
         socket.assigns.create_library_form,
         params
       )
     )}
  end

  def handle_event("submit_create_library", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.create_library_form,
           params: params
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

  def handle_event("open_edit_library_modal", %{"library_id" => library_id}, socket) do
    {library, form} =
      socket.assigns.libraries
      |> Enum.find(&(&1.id == library_id))
      |> case do
        %Library{} = library ->
          form =
            library
            |> Clubs.form_to_update_library(actor: socket.assigns.current_user)
            |> to_form()

          {library, form}

        nil ->
          {nil, nil}
      end

    {:noreply, assign(socket, edit_library: library, edit_library_form: form)}
  end

  def handle_event("validate_edit_library", %{"form" => params}, socket) do
    {:noreply,
     assign(
       socket,
       :edit_library_form,
       AshPhoenix.Form.validate(
         socket.assigns.edit_library_form,
         library_name_params(params)
       )
     )}
  end

  def handle_event("submit_edit_library", %{"form" => params}, socket) do
    submit_edit_library(socket, library_name_params(params))
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

  def handle_event("open_icon_picker", %{"library_id" => library_id}, socket) do
    library = Enum.find(socket.assigns.libraries, &(&1.id == library_id))
    {:noreply, assign(socket, :library_to_update_icon, library)}
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
     |> assign(:edit_library, nil)
     |> assign(:edit_library_form, nil)
     |> assign(:library_to_delete, nil)
     |> assign(:library_to_update_icon, nil)}
  end

  defp submit_edit_library(socket, params) do
    case AshPhoenix.Form.submit(socket.assigns.edit_library_form,
           params: params
         ) do
      {:ok, %Library{} = library} ->
        {:noreply,
         socket
         |> assign(:edit_library, nil)
         |> assign(:edit_library_form, nil)
         |> assign(:libraries, replace_library(socket.assigns.libraries, library))}

      {:error, form} ->
        {:noreply, assign(socket, :edit_library_form, form)}
    end
  end

  defp library_name_params(params), do: Map.take(params, ["name"])

  defp load_libraries_if_needed(socket, club_id, _current_user)
       when socket.assigns.loaded_club_id == club_id do
    socket
  end

  defp load_libraries_if_needed(socket, club_id, _current_user) do
    socket
    |> assign(:loaded_club_id, club_id)
    |> reload_libraries()
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
