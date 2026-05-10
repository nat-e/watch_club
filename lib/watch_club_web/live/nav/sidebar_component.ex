defmodule WatchClubWeb.Live.Nav.SidebarComponent do
  use WatchClubWeb, :live_component

  import WatchClubWeb.Live.Nav.Components.{Modals, Sidebar}

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.sidebar collapsible="offcanvas">
        <:header>
          <div class="flex flex-row justify-between w-full items-center">
            <h2 class="m-2">watch.club</h2>
            <.button
              variant="ghost"
              class="block text-sidebar-foreground p-2 shadow md:hidden"
              phx-click={JS.dispatch("wc:sidebar-toggle", to: "#sidebar")}
            >
              <Lucideicons.x />
            </.button>
          </div>
        </:header>
        <.sidebar_group class="flex flex-col gap-2">
          <.sidebar_menu>
            <.sidebar_nav_button url="/" current_url={@current_url}>
              <:icon><Lucideicons.home /></:icon>
              {dgettext("nav", "Home")}
            </.sidebar_nav_button>
            <.sidebar_nav_button url="/watchlist" current_url={@current_url}>
              <:icon><Lucideicons.bookmark /></:icon>
              {dgettext("nav", "Watchlist")}
            </.sidebar_nav_button>
          </.sidebar_menu>
        </.sidebar_group>
        <.sidebar_group class="flex flex-col gap-2">
          <:label>{dgettext("nav", "Clubs")}</:label>
          <.sidebar_menu>
            <.sidebar_membership_menu_item
              :for={membership <- @current_user.memberships}
              myself={@myself}
              current_url={@current_url}
              membership={membership}
            />
          </.sidebar_menu>
          <.sidebar_menu :if={@current_user.administrator?}>
            <.sidebar_menu_item
              phx-click="open_create_club_modal"
              phx-target={@myself}
              size="lg"
            >
              <:icon><Lucideicons.plus class="size-8 px-1" /></:icon>
              {dgettext("nav", "Create new club")}
            </.sidebar_menu_item>
          </.sidebar_menu>
        </.sidebar_group>
      </.sidebar>
      <.create_club_modal :if={@create_club_form} form={@create_club_form} myself={@myself} />
      <.delete_club_modal :if={@club_to_delete} club={@club_to_delete} myself={@myself} />
      <.leave_club_modal
        :if={@membership_to_leave}
        membership={@membership_to_leave}
        myself={@myself}
      />
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket |> reset_modals()}
  end

  @impl true
  def handle_event("open_create_club_modal", _params, socket) do
    form = Clubs.form_to_create_club(actor: socket.assigns.current_user)

    {:noreply, socket |> assign(:create_club_form, to_form(form))}
  end

  def handle_event("validate_create_club", %{"form" => params}, socket) do
    {:noreply,
     socket
     |> assign(
       :create_club_form,
       AshPhoenix.Form.validate(socket.assigns.create_club_form, params)
     )}
  end

  def handle_event("create_club", %{"form" => params}, socket) do
    %{create_club_form: form, current_user: user} = socket.assigns

    case AshPhoenix.Form.submit(form, params: params, read_one?: true, actor: user) do
      {:ok, club} ->
        WatchClubWeb.Hooks.Flash.send_flash(
          :success,
          dgettext("clubs", "Club %{club_name} created", club_name: club.name)
        )

        {:noreply, socket |> assign(:create_club_form, nil)}

      {:error, form} ->
        {:noreply, socket |> assign(:create_club_form, form)}
    end
  end

  def handle_event("open_delete_club_modal", %{"club_id" => club_id}, socket) do
    memberships = socket.assigns.current_user.memberships
    %Membership{club: club} = Enum.find(memberships, fn m -> m.club.id == club_id end)

    {:noreply, socket |> assign(:club_to_delete, club)}
  end

  def handle_event("delete_club", %{"club_id" => club_id}, socket) do
    %{current_user: user} = socket.assigns
    %Membership{club: club} = Enum.find(user.memberships, fn m -> m.club.id == club_id end)

    case Clubs.destroy_club(club, actor: user) do
      :ok ->
        WatchClubWeb.Hooks.Flash.send_flash(
          :success,
          dgettext("clubs", "Club %{club_name} deleted", club_name: club.name)
        )

      {:error, error} ->
        Logger.error("Error deleting club: #{inspect(error)}")

        WatchClubWeb.Hooks.Flash.send_flash(
          :error,
          dgettext("clubs", "Error deleting club, try again later")
        )
    end

    {:noreply, socket |> assign(:club_to_delete, nil)}
  end

  def handle_event("open_leave_club_modal", %{"membership_id" => membership_id}, socket) do
    memberships = socket.assigns.current_user.memberships
    membership = Enum.find(memberships, fn m -> m.id == membership_id end)

    {:noreply, socket |> assign(:membership_to_leave, membership)}
  end

  def handle_event("leave_club", %{"membership_id" => membership_id}, socket) do
    %{current_user: user} = socket.assigns
    membership = Enum.find(user.memberships, fn m -> m.id == membership_id end)

    case Clubs.leave_club(membership, actor: user) do
      :ok ->
        WatchClubWeb.Hooks.Flash.send_flash(
          :success,
          dgettext("clubs", "You left %{club_name}", club_name: membership.club.name)
        )

      {:error, error} ->
        Logger.error("Error leaving club: #{inspect(error)}")

        WatchClubWeb.Hooks.Flash.send_flash(
          :error,
          dgettext("clubs", "Error leaving club, try again later")
        )
    end

    {:noreply, socket |> assign(:membership_to_leave, nil)}
  end

  def handle_event("close_modals", _params, socket) do
    {:noreply, socket |> reset_modals()}
  end

  defp reset_modals(socket) do
    socket
    |> assign(:create_club_form, nil)
    |> assign(:club_to_delete, nil)
    |> assign(:membership_to_leave, nil)
  end
end
