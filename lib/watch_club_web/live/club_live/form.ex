defmodule WatchClubWeb.ClubLive.Form do
  alias WatchClub.Clubs
  use WatchClubWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage club records in your database.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="club-form"
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" phx-debounce="blur" />

        <.button phx-disable-with="Saving..." variant="primary">Save Club</.button>
        <.button navigate={return_path(@return_to, @club)}>Cancel</.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    club =
      case params["id"] do
        nil -> nil
        id -> Clubs.get_club!(id)
      end

    action = if is_nil(club), do: "New", else: "Edit"
    page_title = action <> " " <> "Club"

    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(club: club)
     |> assign(:page_title, page_title)
     |> assign_form()}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  @impl true
  def handle_event("validate", %{"club" => club_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, club_params))}
  end

  def handle_event("save", %{"club" => club_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: club_params) do
      {:ok, club} ->
        socket =
          socket
          |> put_flash(:info, "Club #{socket.assigns.form.source.type}d successfully")
          |> push_navigate(to: return_path(socket.assigns.return_to, club))

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp assign_form(%{assigns: %{club: club}} = socket) do
    form =
      if club do
        AshPhoenix.Form.for_update(club, :update, as: "club")
      else
        AshPhoenix.Form.for_create(WatchClub.Clubs.Club, :create, as: "club")
      end

    assign(socket, form: to_form(form))
  end

  defp return_path("index", _club), do: ~p"/clubs"
  defp return_path("show", club), do: ~p"/clubs/#{club.id}"
end
