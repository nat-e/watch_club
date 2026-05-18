defmodule WatchClubWeb.Clubs.SettingsPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Settings.SettingsHeader
  import WatchClubWeb.Components.Settings.SettingsSection

  alias WatchClubWeb.Clubs.Settings.LibrariesLive

  @impl true
  def render(%{club: %Club{}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      space="section"
      class="max-w-panel"
    >
      <.settings_header
        title={dgettext("clubs", "Club Settings")}
        description={
          dgettext("clubs", "Manage %{club_name}'s profile and libraries.", club_name: @club.name)
        }
      />

      <.settings_section
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
      </.settings_section>

      <.live_component
        module={LibrariesLive}
        id={"club-libraries-#{@club.id}"}
        club={@club}
        current_user={@current_user}
      />
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
          |> assign(:club, club)
          |> assign(:form, to_form(form))

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
        {:noreply, assign(socket, :club, updated_club)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp get_club_settings(club_id, actor) do
    Clubs.get_club_by_id(club_id, actor: actor)
  end

  defp not_found(socket) do
    {:noreply,
     socket
     |> put_flash(:error, dgettext("clubs", "The club you were looking for does not exist"))
     |> push_navigate(to: ~p"/")}
  end

  defp form_opts(actor) do
    [
      actor: actor,
      transform_errors: fn
        _, %Ash.Error.Changes.Required{field: :name} ->
          {:name, dgettext("clubs", "You must enter a club name"), []}

        _, err ->
          Logger.warning("Unexpected form error: #{inspect(err)}")
          err
      end
    ]
  end
end
