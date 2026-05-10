defmodule WatchClubWeb.ClubsLive.Settings do
  use WatchClubWeb, :live_view

  import WatchClubWeb.ClubsLive.LibraryManagementComponents

  @impl true
  def render(%{club: %Club{}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      class="p-4 flex flex-col gap-12"
    >
      <h1 class="text-2xl font-bold">{dgettext("clubs", "Club Settings")}</h1>

      <.settings_section
        title={dgettext("clubs", "General")}
        description={dgettext("clubs", "Update the basic club information.")}
      >
        <form
          id="update_club_form"
          phx-change="validate_update_club"
          phx-submit="submit_update_club"
          class="flex flex-col gap-6"
          phx-mounted={JS.focus_first()}
        >
          <.input_with_label field={@form[:name]} label={dgettext("clubs", "Club Name")}>
            <.input
              field={@form[:name]}
              type="text"
              phx-debounce="blur"
              class="w-full sm:w-80"
            />
          </.input_with_label>
          <.button type="submit" class="w-fit">
            {dgettext("clubs", "Edit Club")}
          </.button>
        </form>
      </.settings_section>

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
          <.button phx-click="open_create_library_modal">
            <Lucideicons.plus />
            {dgettext("clubs", "Create library")}
          </.button>
        </:action>

        <.libraries_empty_state :if={@libraries == []} />
        <.library_list :if={@libraries != []} libraries={@libraries} />
      </.settings_section>

      <.create_library_modal
        :if={@create_library_form}
        form={@create_library_form}
        content_types={ContentType.values()}
      />
      <.delete_library_modal :if={@library_to_delete} library={@library_to_delete} />
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_url={@current_url} current_user={@current_user}></Layouts.app>
    """
  end

  @impl true
  def handle_params(%{"club_id" => club_id}, _uri, socket) do
    case get_club_settings(club_id, socket.assigns.current_user) do
      {:ok, club} ->
        form = Clubs.form_to_update_club(club, form_opts(socket.assigns.current_user))

        socket =
          socket
          |> assign_club_settings(club)
          |> assign(:form, to_form(form))
          |> assign(:create_library_form, nil)
          |> assign(:library_to_delete, nil)

        {:noreply, socket}

      {:error, %Ash.Error.Query.NotFound{}} ->
        not_found(socket)

      {:error, %Ash.Error.Invalid{}} ->
        not_found(socket)

      {:error, %Ash.Error.Forbidden{}} ->
        not_found(socket)

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate_update_club", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit_update_club", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, updated_club} ->
        {:noreply, socket |> assign(:club, updated_club)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

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
        {:noreply,
         socket
         |> put_flash(:success, dgettext("clubs", "Library created"))
         |> assign(:create_library_form, nil)
         |> reload_club_settings()}

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
      :ok ->
        {:noreply, reload_club_settings(socket)}

      {:error, error} ->
        Logger.warning("Error reordering libraries: #{inspect(error)}")

        {:noreply,
         socket
         |> put_flash(:error, dgettext("clubs", "Error reordering libraries, try again later"))
         |> reload_club_settings()}
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
            {:noreply,
             socket
             |> put_flash(:success, dgettext("clubs", "Library deleted"))
             |> assign(:library_to_delete, nil)
             |> reload_club_settings()}

          {:error, error} ->
            Logger.warning("Error deleting library: #{inspect(error)}")

            {:noreply,
             socket
             |> put_flash(:error, dgettext("clubs", "Error deleting library, try again later"))
             |> assign(:library_to_delete, nil)}
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

  defp rename_library(socket, library, name) do
    case Clubs.update_library(library, %{name: name}, actor: socket.assigns.current_user) do
      {:ok, %Library{} = library} ->
        {:noreply, assign(socket, :libraries, replace_library(socket.assigns.libraries, library))}

      {:error, error} ->
        Logger.warning("Error renaming library: #{inspect(error)}")

        {:noreply,
         put_flash(socket, :error, dgettext("clubs", "Error renaming library, try again later"))}
    end
  end

  defp reload_club_settings(socket) do
    case get_club_settings(socket.assigns.club.id, socket.assigns.current_user) do
      {:ok, club} ->
        assign_club_settings(socket, club)

      {:error, error} ->
        Logger.warning("Error loading club settings: #{inspect(error)}")
        put_flash(socket, :error, dgettext("clubs", "Could not load club settings"))
    end
  end

  defp get_club_settings(club_id, actor) do
    Clubs.get_club_by_id(club_id, actor: actor, load: [:libraries])
  end

  defp assign_club_settings(socket, %Club{} = club) do
    socket
    |> assign(:club, club)
    |> assign(:libraries, club.libraries)
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
      end,
      transform_errors: &transform_library_errors/2
    )
    |> to_form()
  end

  defp transform_library_errors(_, %Ash.Error.Changes.Required{field: :name}) do
    {:name, dgettext("clubs", "You must enter a library name"), []}
  end

  defp transform_library_errors(_, %Ash.Error.Changes.Required{field: :content_type}) do
    {:content_type, dgettext("clubs", "You must select a content type"), []}
  end

  defp transform_library_errors(_, error), do: error

  defp replace_library(libraries, %Library{} = updated_library) do
    Enum.map(libraries, fn
      %Library{id: id} when id == updated_library.id -> updated_library
      library -> library
    end)
  end

  defp not_found(socket) do
    {:noreply,
     socket
     |> put_flash(:error, dgettext("clubs", "The club you were looking for does not exist"))
     |> redirect(to: ~p"/")}
  end

  defp form_opts(actor) do
    [
      actor: actor,
      transform_errors: fn
        _, %Ash.Error.Changes.Required{field: :name} ->
          {:name, "You must enter a club name", []}

        _, err ->
          Logger.warning("Unexpected form error: #{inspect(err)}")
          err
      end
    ]
  end
end
