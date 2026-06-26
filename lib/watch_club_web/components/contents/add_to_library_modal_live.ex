defmodule WatchClubWeb.Components.Contents.AddToLibraryModalLive do
  use WatchClubWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal
        id="club-selection-modal"
        on_close={JS.push("close", target: @myself)}
      >
        <:title>{dgettext("contents", "Share with club")}</:title>
        <.stack space="group" class="relative w-full max-w-lg">
          <.alert>
            <:icon><Lucideicons.users class="size-icon-xl" /></:icon>
            {raw(
              dgettext(
                "contents",
                "Select the Club Library in which you want to add %{content_name}. All Club members will be able to access and see this content.",
                content_name: gtspan(@content_title, "font-bold underline")
              )
            )}
          </.alert>
          <.stack space="group">
            <h2 class="text-lg font-bold">{dgettext("contents", "Select library")}</h2>
            <.form
              for={%{}}
              id="club-selection-form"
              phx-target={@myself}
              phx-submit="submit"
            >
              <.library_selection_checkbox
                :for={option <- @library_options}
                club={option.club}
                library={option.library}
                already_in?={option.already_in?}
              />
              <:action>
                <.button
                  id="club-selection-submit-button"
                  type="submit"
                  disabled={Enum.all?(@library_options, & &1.already_in?)}
                >
                  {dgettext("default", "Save")}
                </.button>
              </:action>
            </.form>
          </.stack>
        </.stack>
      </.modal>
    </div>
    """
  end

  defp library_selection_checkbox(%{already_in?: true} = assigns) do
    ~H"""
    <div class="flex min-h-row-lg w-full flex-row items-center justify-between rounded-md border border-border bg-surface-selected p-group text-text">
      <div class="flex min-w-0 flex-row items-center gap-related">
        <.avatar id={@club.id} name={@club.name} />
        <div class="min-w-0">
          <p class="truncate font-bold">{@club.name}</p>
          <p class="truncate text-sm text-text-muted">{@library.name}</p>
        </div>
      </div>
      <.badge variant="success">
        {dgettext("contents", "Already added")}
      </.badge>
    </div>
    """
  end

  defp library_selection_checkbox(assigns) do
    ~H"""
    <label class="flex min-h-row-lg w-full flex-row items-center justify-between rounded-md border border-border p-group transition-colors hover:bg-surface-hover active:bg-surface-active">
      <div class="flex min-w-0 flex-row items-center gap-related">
        <.avatar id={@club.id} name={@club.name} />
        <div class="min-w-0">
          <p class="truncate font-bold">{@club.name}</p>
          <p class="truncate text-sm text-text-muted">{@library.name}</p>
        </div>
      </div>
      <.checkbox
        id={"library-checkbox-#{@library.id}"}
        name="form[library_ids][]"
        value={@library.id}
      />
    </label>
    """
  end

  # No need to support update_many for a modal
  @impl true
  def update(assigns, socket) do
    identity = assigns.content_identity

    library_items =
      Clubs.get_library_items_by_identities!([identity],
        actor: assigns.current_user,
        load: [:content, library: [:club]]
      )

    library_options =
      assigns.current_user.memberships
      |> Enum.flat_map(fn membership ->
        membership.club.libraries
        |> Enum.filter(&(&1.content_type == identity.type))
        |> Enum.map(fn library ->
          %{
            club: membership.club,
            library: library,
            already_in?: library_items |> Enum.any?(&(library.id == &1.library_id))
          }
        end)
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(library_options: library_options)}
  end

  # Adds the Content to the newly-checked libraries. Already-in and
  # type-mismatched libraries aren't selectable, so this only ever adds. The bulk
  # action broadcasts a single content_changed, so the parent reloads.
  @impl true
  def handle_event("submit", params, socket) do
    case (params["form"] && params["form"]["library_ids"]) || [] do
      [] ->
        socket.assigns.on_close.()
        {:noreply, socket}

      library_ids ->
        case Clubs.add_content_to_libraries(socket.assigns.content_identity, library_ids,
               actor: socket.assigns.current_user
             ) do
          {:ok, _} ->
            socket.assigns.on_close.()
            {:noreply, socket}

          {:error, error} ->
            socket.assigns.on_close.()
            Logger.warning("Error adding to libraries: #{inspect(error)}")

            WatchClubWeb.Hooks.Flash.send_flash(
              :error,
              dgettext("default", "Something went wrong, try again later")
            )

            {:noreply, socket}
        end
    end
  end

  def handle_event("close", _params, socket) do
    socket.assigns.on_close.()
    {:noreply, socket}
  end
end
