defmodule WatchClubWeb.Live.Nav.SidebarComponent do
  use WatchClubWeb, :live_component

  import WatchClubWeb.Live.Nav.Components.Modals

  @sidebar_transition_time 200

  def show_sidebar(js \\ %JS{}) do
    js
    |> JS.remove_class("invisible pointer-events-none", to: "#sidebar-backdrop")
    |> JS.remove_class("opacity-0", to: "#sidebar-backdrop")
    |> JS.remove_class("-translate-x-full", to: "#sidebar-panel")
    |> JS.focus_first(to: "#sidebar-panel")
  end

  def hide_sidebar(js \\ %JS{}) do
    js
    |> JS.add_class("-translate-x-full", to: "#sidebar-panel")
    |> JS.add_class("opacity-0", to: "#sidebar-backdrop")
    |> JS.add_class("pointer-events-none", to: "#sidebar-backdrop")
    |> JS.add_class(
      "invisible",
      to: "#sidebar-backdrop",
      time: @sidebar_transition_time,
      blocking: false,
      transition: {"transition-opacity duration-200", "opacity-100", "opacity-100"}
    )
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :current_path, assigns.current_url.path)

    ~H"""
    <div id="sidebar-shell" phx-window-keydown={hide_sidebar()} phx-key="escape">
      <button
        id="sidebar-backdrop"
        type="button"
        aria-label={dgettext("nav", "Close navigation")}
        class="invisible fixed inset-0 z-40 pointer-events-none bg-canvas/70 opacity-0 backdrop-blur-sm transition-opacity duration-200 ease-out md:hidden"
        phx-click={hide_sidebar()}
      />

      <aside
        id="sidebar-panel"
        class="fixed inset-y-0 left-0 z-50 flex w-[80vw] -translate-x-full flex-col overflow-hidden border-r border-border-subtle bg-surface text-text shadow-overlay transition-transform duration-200 ease-out will-change-transform md:z-20 md:w-[var(--wc-sidebar-width)] md:translate-x-0 md:shadow-none"
      >
        <header class="flex h-row-lg shrink-0 items-center justify-between px-cluster">
          <h2 class="font-heading text-xl font-semibold">watch.club</h2>
          <.button
            variant="ghost"
            size="icon-sm"
            class="md:hidden"
            aria-label={dgettext("nav", "Close navigation")}
            phx-click={hide_sidebar()}
          >
            <Lucideicons.x />
          </.button>
        </header>

        <nav
          aria-label={dgettext("nav", "Main navigation")}
          class="flex flex-1 flex-col gap-group overflow-y-auto p-group"
        >
          <ul class="flex list-none flex-col gap-tight p-0">
            <li>
              <.sidebar_item href="/" active={active?(@current_path, "/")}>
                <Lucideicons.home />
                <span class="min-w-0 flex-1 truncate">{dgettext("nav", "Home")}</span>
              </.sidebar_item>
            </li>
            <li>
              <.sidebar_item href="/watchlist" active={active?(@current_path, "/watchlist")}>
                <Lucideicons.bookmark />
                <span class="min-w-0 flex-1 truncate">{dgettext("nav", "Watchlist")}</span>
              </.sidebar_item>
            </li>
          </ul>

          <h3 class="px-group pt-related text-xs font-semibold tracking-wide text-text-subtle uppercase">
            {dgettext("nav", "Clubs")}
          </h3>

          <ul class="flex list-none flex-col gap-tight p-0">
            <.club_nav_item
              :for={membership <- @current_user.memberships}
              membership={membership}
              current_path={@current_path}
              myself={@myself}
            />

            <li :if={@current_user.administrator?}>
              <.sidebar_item on_click={
                JS.push("open_create_club_modal", target: @myself) |> hide_sidebar()
              }>
                <Lucideicons.plus />
                <span class="min-w-0 flex-1 truncate">{dgettext("nav", "Create new club")}</span>
              </.sidebar_item>
            </li>
          </ul>
        </nav>
      </aside>

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

  attr :href, :string, default: nil
  attr :active, :boolean, default: false
  attr :class, :any, default: nil
  attr :on_click, :any, default: nil

  slot :inner_block, required: true

  defp sidebar_item(assigns) do
    assigns =
      assigns
      |> assign(:on_click, assigns.on_click || hide_sidebar())
      |> assign(:rest, if(assigns.href, do: %{href: assigns.href}, else: %{}))

    ~H"""
    <.button
      variant="ghost"
      size="md"
      type="button"
      aria-current={@active && "page"}
      class={[
        "min-h-touch-target w-full justify-start overflow-hidden text-left font-medium",
        @active &&
          "!bg-surface-selected !text-text shadow-sm hover:!bg-surface-selected active:!bg-surface-selected",
        @class
      ]}
      phx-click={@on_click}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.button>
    """
  end

  attr :membership, Membership, required: true
  attr :current_path, :string, required: true
  attr :myself, :any, required: true

  defp club_nav_item(assigns) do
    url = "/clubs/#{assigns.membership.club.id}"

    assigns =
      assigns
      |> assign(:url, url)
      |> assign(:active, active?(assigns.current_path, url))

    ~H"""
    <li class={[
      "flex min-h-touch-target items-center overflow-hidden rounded-control border border-transparent transition-colors duration-150",
      @active && "bg-surface-selected text-text shadow-sm",
      !@active &&
        "text-text-muted hover:bg-surface-hover hover:text-text active:bg-surface-active [&:has([data-club-nav-actions]:hover)]:!bg-transparent [&:has([data-club-nav-actions]:hover)]:!text-text-muted"
    ]}>
      <.button
        href={@url}
        variant="ghost"
        size="md"
        aria-current={@active && "page"}
        class="min-h-touch-target min-w-0 flex-1 justify-start rounded-none !bg-transparent !text-inherit hover:!bg-transparent hover:!text-inherit active:!bg-transparent"
        phx-click={hide_sidebar()}
      >
        <.avatar id={@membership.club.id} name={@membership.club.name} />
        <span class="min-w-0 flex-1 truncate">{@membership.club.name}</span>
      </.button>

      <.dropdown_menu class="shrink-0 pr-tight">
        <:trigger>
          <.button
            size="icon-sm"
            variant="ghost"
            aria-label={dgettext("nav", "Club actions")}
            data-club-nav-actions
            class="!text-inherit hover:!bg-surface-hover hover:!text-text active:!bg-surface-active"
          >
            <Lucideicons.ellipsis_vertical />
          </.button>
        </:trigger>

        <.dropdown_menu_item
          :if={@membership.role == :admin}
          href={"#{@url}/members"}
          phx-click={hide_sidebar()}
        >
          <Lucideicons.user />{dgettext("clubs", "Manage members")}
        </.dropdown_menu_item>
        <.dropdown_menu_item
          :if={@membership.role == :admin}
          href={"#{@url}/settings"}
          phx-click={hide_sidebar()}
        >
          <Lucideicons.settings />{dgettext("clubs", "Club Settings")}
        </.dropdown_menu_item>
        <.dropdown_menu_separator :if={@membership.role == :admin} />
        <.dropdown_menu_item
          :if={@membership.role == :admin}
          phx-click={
            JS.push("open_delete_club_modal",
              target: @myself,
              value: %{club_id: @membership.club.id}
            )
            |> hide_sidebar()
          }
          variant="destructive"
        >
          <Lucideicons.trash />{dgettext("clubs", "Delete club")}
        </.dropdown_menu_item>
        <.dropdown_menu_item
          :if={@membership.role == :member}
          phx-click={
            JS.push("open_leave_club_modal",
              target: @myself,
              value: %{membership_id: @membership.id}
            )
            |> hide_sidebar()
          }
          variant="destructive"
        >
          <Lucideicons.door_open />{dgettext("clubs", "Leave club")}
        </.dropdown_menu_item>
      </.dropdown_menu>
    </li>
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

  defp active?(current_path, "/"), do: current_path == "/"

  defp active?(current_path, url),
    do: current_path == url || String.starts_with?(current_path, url <> "/")

  defp reset_modals(socket) do
    socket
    |> assign(:create_club_form, nil)
    |> assign(:club_to_delete, nil)
    |> assign(:membership_to_leave, nil)
  end
end
