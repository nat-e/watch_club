defmodule WatchClubWeb.ClubsLive.Settings do
  use WatchClubWeb, :live_view

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
            class="w-80"
          />
        </.input_with_label>
        <.button type="submit" class="w-30">
          {dgettext("clubs", "Edit Club")}
        </.button>
      </form>
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
    case Clubs.get_club_by_id(club_id, actor: socket.assigns.current_user) do
      {:ok, club} ->
        form = Clubs.form_to_update_club(club, form_opts(socket.assigns.current_user))
        {:noreply, socket |> assign(:club, club) |> assign(:form, to_form(form))}

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
