defmodule WatchClubWeb.Modals.CreateClub do
  use WatchClubWeb, :live_component

  alias Ash.Error.Changes.{InvalidAttribute, Required}

  @modal_name "create_club"
  def modal_name, do: @modal_name

  @impl true
  def render(%{current_user: %User{}} = assigns) do
    ~H"""
    <div>
      <.dialog>
        <:title>Create a new club</:title>
        <:description>
          Create a new club to share your favorite movies and TV shows with your friends.
        </:description>
        <.form
          :if={@form}
          for={@form}
          id="create-club-form"
          phx-change="validate"
          phx-submit="submit"
          phx-target={@myself}
          class="flex flex-col gap-6"
        >
          <div class="flex flex-col gap-2">
            <.label field={@form[:name]}>Club name</.label>
            <.input
              field={@form[:name]}
              type="text"
              phx-debounce="blur"
            />
            <.field_errors field={@form[:name]} />
          </div>
          <.button type="submit" class="w-full">
            Create
          </.button>
        </.form>
      </.dialog>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    form = Clubs.form_to_create_club(form_opts(assigns))

    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("submit", %{"form" => params}, socket) do
    %{form: form, current_user: user} = socket.assigns

    case AshPhoenix.Form.submit(form, params: params, read_one?: true, actor: user) do
      {:ok, club} ->
        send(self(), {:close_modal, @modal_name, []})
        send(self(), {:put_flash, :success, "Club #{club.name} created"})
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp form_opts(assigns) do
    [
      actor: assigns.current_user,
      # Default role for the member
      transform_errors: fn
        _, %InvalidAttribute{field: :name, vars: [min: min]} ->
          {:name, "Name must be at least %{min} characters", min: min}

        _, %InvalidAttribute{field: :name, vars: [max: max]} ->
          {:name, "Name cannot be longer than %{max} characters", max: max}

        _, %Required{field: :name} ->
          {:name, "You must enter a name for your club", []}

        _, err ->
          Logger.warning("Unexpected form error: #{inspect(err)}")
          err
      end
    ]
  end
end
