defmodule WatchClubWeb.Components.Contents.AddToLibraryButtonLive do
  use WatchClubWeb, :live_component

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.LibraryItem
  alias WatchClub.Contents.ContentIdentity

  @doc """
  The DOM id we recommend using for this Live Component
  Stable DOM id allows us to simplify PubSub notification handling
  """
  def dom_id(%ContentIdentity{} = identity),
    do: "add-to-library-button-#{identity.external_id_source}-#{identity.external_id}"

  @doc """
  Updates the component when a relevant Ash Notification is received.
  We recommend using it on every LiveView that uses this LiveComponent for reactivity.
  This requires using dom_id() as the ID for the LiveComponent and the LiveView to have
  subscribed to the correct topics via `WatchClub.PubSub.subscribe_to_current_user_content_topics`.

  The button refreshes when contents are added or removed from Libraries
  """
  def handle_pubsub_message(
        %Ash.Notifier.Notification{
          resource: LibraryItem,
          metadata: %{content_identity: identity}
        },
        %User{} = user
      ) do
    send_update(__MODULE__,
      id: dom_id(identity),
      content_identity: identity,
      current_user: user
    )
  end

  def handle_pubsub_message(_msg, _user), do: nil

  attr :content_identity, ContentIdentity, required: true
  attr :content_title, :string, required: true
  attr :current_user, User, required: true
  attr :class, :any, default: nil

  attr :size, :string,
    values: ~w(sm md lg),
    default: "md"

  @impl true
  def render(assigns) do
    ~H"""
    <div class={@class}>
      <.button
        id={"#{@id}-open-button"}
        size={@size}
        variant={if @library_items == [], do: "primary", else: "accent"}
        class="w-full"
        phx-target={@myself}
        phx-click="open"
      >
        <.inner library_items={@library_items} />
      </.button>
      <.library_selection_modal
        :if={@open?}
        component_id={@id}
        content_identity={@content_identity}
        content_title={@content_title}
        library_items={@library_items}
        current_user={@current_user}
        myself={@myself}
      />
    </div>
    """
  end

  defp inner(%{library_items: []} = assigns) do
    ~H"""
    <Lucideicons.list_plus />
    <span>{dgettext("contents", "Share with Clubs")}</span>
    """
  end

  defp inner(assigns) do
    assigns = assigns |> assign(clubs: assigns.library_items |> Enum.map(& &1.library.club))

    ~H"""
    <.avatar_group avatars={@clubs} avatar_size="sm" />
    <.count_label count={length(@clubs)} />
    """
  end

  attr :count, :integer, required: true

  defp count_label(assigns) do
    ~H"""
    <span class="mr-tight">
      {dngettext("contents", "In %{count} club", "In %{count} clubs", @count)}
    </span>
    """
  end

  defp library_selection_modal(assigns) do
    assigns =
      assigns
      |> assign(
        library_options:
          libraries_for_content(
            assigns.current_user,
            assigns.content_identity.type,
            assigns.library_items
          )
      )

    ~H"""
    <.modal id="club-selection-modal" on_close={JS.push("close", target: @myself)}>
      <:title>{dgettext("contents", "Share with club")}</:title>
      <.stack space="group" class="relative w-full max-w-lg">
        <.alert variant="accent">
          <:icon><Lucideicons.users class="size-icon-xl" /></:icon>
          {raw(
            dgettext(
              "contents",
              "Select the Club Library in which you want to add %{content_name}. All Club members will be able to access and see this content.",
              content_name: gtboldunder(@content_title)
            )
          )}
        </.alert>
        <.stack space="group">
          <h2 class="text-lg font-bold">{dgettext("contents", "Select library")}</h2>
          <.form
            for={%{}}
            id={"#{@component_id}-club-selection-form"}
            phx-target={@myself}
            phx-submit="submit"
          >
            <.library_selection_checkbox
              :for={option <- @library_options}
              component_id={@component_id}
              club={option.club}
              library={option.library}
              already_in?={option.already_in?}
            />
            <:action>
              <.button
                id={"#{@component_id}-club-selection-submit-button"}
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
        {dgettext("contents", "Already in %{library}", library: @library.name)}
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
        id={"#{@component_id}-library-checkbox-#{@library.id}"}
        name="form[library_ids][]"
        value={@library.id}
      />
    </label>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :open?, false)}
  end

  @impl true
  def update_many(assigns_sockets) do
    identities = Enum.map(assigns_sockets, fn {assigns, _socket} -> assigns.content_identity end)

    actor = assigns_sockets |> List.first() |> Kernel.elem(0) |> Map.fetch!(:current_user)

    items_by_identity =
      Clubs.get_library_items_by_identities!(identities,
        actor: actor,
        load: [:content, library: [:club]]
      )
      |> Enum.group_by(&ContentIdentity.from_content(&1.content))

    assigns_sockets
    |> Enum.map(fn {assigns, socket} ->
      socket
      |> assign(assigns)
      |> assign(library_items: Map.get(items_by_identity, assigns.content_identity, []))
    end)
  end

  # Just toggles the modal — the checkboxes carry the selection and the bulk
  # actions resolve (and create) the Content from its identity, so there's no
  # form state to track.
  @impl true
  def handle_event("open", _params, socket) do
    {:noreply, assign(socket, :open?, true)}
  end

  @impl true
  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, :open?, false)}
  end

  # Adds the Content to the newly-checked libraries. Already-in and
  # type-mismatched libraries aren't selectable, so this only ever adds. The bulk
  # action broadcasts a single content_changed, so the parent reloads.
  def handle_event("submit", params, socket) do
    case (params["form"] && params["form"]["library_ids"]) || [] do
      [] ->
        {:noreply, assign(socket, :open?, false)}

      library_ids ->
        case Clubs.add_content_to_libraries(socket.assigns.content_identity, library_ids,
               actor: socket.assigns.current_user
             ) do
          {:ok, _} ->
            {:noreply, assign(socket, :open?, false)}

          {:error, error} ->
            Logger.warning("Error adding to libraries: #{inspect(error)}")

            WatchClubWeb.Hooks.Flash.send_flash(
              :error,
              dgettext("default", "Something went wrong, try again later")
            )

            {:noreply, socket}
        end
    end
  end

  # The actor's club libraries that accept this content's type, marking the ones
  # it is already in (shown as a badge, not a selectable checkbox).
  defp libraries_for_content(%User{} = user, content_type, library_items) do
    user.memberships
    |> Enum.flat_map(fn membership ->
      membership.club.libraries
      |> Enum.filter(&(&1.content_type == content_type))
      |> Enum.map(fn library ->
        %{
          club: membership.club,
          library: library,
          already_in?: library_items |> Enum.any?(&(library.id == &1.library_id))
        }
      end)
    end)
  end
end
