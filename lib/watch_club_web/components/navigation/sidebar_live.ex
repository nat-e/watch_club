defmodule WatchClubWeb.Components.Navigation.SidebarLive do
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Libraries.LibraryIcon
  import WatchClubWeb.Components.Navigation.Sidebar.CreateClubModal
  import WatchClubWeb.Components.Navigation.Sidebar.DeleteClubModal
  import WatchClubWeb.Components.Navigation.Sidebar.LeaveClubModal

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
        class="invisible fixed inset-0 z-40 pointer-events-none bg-scrim opacity-0 backdrop-blur-sm transition-opacity duration-200 ease-out md:hidden"
        phx-click={hide_sidebar()}
      />

      <aside
        id="sidebar-panel"
        class="fixed inset-y-0 left-0 z-50 flex w-[80vw] -translate-x-full flex-col overflow-hidden border-r border-border-subtle bg-surface text-text shadow-overlay transition-transform duration-200 ease-out will-change-transform md:z-20 md:w-[var(--wc-sidebar-width)] md:translate-x-0 md:shadow-none"
      >
        <header class="flex h-row-lg shrink-0 items-center justify-between px-cluster">
          <h2 class="font-heading text-xl font-semibold">watch.club</h2>
          <.button
            id="sidebar-close-button"
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
              <.sidebar_item
                id="sidebar-home-link"
                navigate={~p"/"}
                active={active?(@current_path, "/")}
              >
                <Lucideicons.home />
                <span class="min-w-0 flex-1 truncate">{dgettext("nav", "Home")}</span>
              </.sidebar_item>
            </li>
            <li>
              <.sidebar_item
                id="sidebar-my-requests-link"
                navigate={~p"/my-requests"}
                active={active?(@current_path, "/my-requests")}
              >
                <Lucideicons.inbox />
                <span class="min-w-0 flex-1 truncate">{dgettext("nav", "My Requests")}</span>
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
              <.sidebar_item
                id="sidebar-create-club-button"
                on_click={JS.push("open_create_club_modal", target: @myself) |> hide_sidebar()}
              >
                <Lucideicons.plus />
                <span class="min-w-0 flex-1 truncate">{dgettext("nav", "Create new club")}</span>
              </.sidebar_item>
            </li>
          </ul>

          <%!--
            mt-auto pushes Admin to the bottom of the scroll viewport when there is room,
            and lets it scroll naturally with the rest of the nav when there isn't.
          --%>
          <div
            :if={@current_user.administrator?}
            class="mt-auto flex flex-col gap-tight -mx-group border-t border-border-subtle px-group pt-group"
          >
            <h3 class="px-group text-xs font-semibold tracking-wide text-text-subtle uppercase">
              {dgettext("nav", "Admin")}
            </h3>
            <ul class="flex list-none flex-col gap-tight p-0">
              <.admin_links current_path={@current_path} />
            </ul>
          </div>
        </nav>

        <%!--
          Reuses the --club-nav-rail-offset trick (left padding + half the avatar size)
          so Settings hangs under the user avatar like libraries hang under a club.
        --%>
        <div class={[
          "flex flex-col gap-tight border-t border-border-subtle p-group",
          "[--club-nav-avatar-size:2rem]",
          "[--club-nav-rail-offset:calc(var(--wc-space-group)_+_(var(--club-nav-avatar-size)_/_2))]"
        ]}>
          <div class="flex min-h-touch-target items-center gap-related px-group text-sm font-semibold text-text">
            <.avatar id={@current_user.id} name={@current_user.username} size="md" />
            <span class="min-w-0 flex-1 truncate">{@current_user.username}</span>
            <.button
              id="sidebar-sign-out-button"
              variant="ghost"
              size="icon"
              href={~p"/sign-out"}
              method="delete"
              aria-label={dgettext("nav", "Sign out")}
            >
              <Lucideicons.log_out class="text-danger" />
            </.button>
          </div>
          <ul class="ml-[var(--club-nav-rail-offset)] flex list-none flex-col gap-tight border-l border-border-subtle py-tight pl-related">
            <li>
              <.sidebar_item
                id="sidebar-settings-link"
                navigate={~p"/settings"}
                active={active?(@current_path, "/settings")}
              >
                <Lucideicons.settings />
                <span class="min-w-0 flex-1 truncate">{dgettext("nav", "Settings")}</span>
              </.sidebar_item>
            </li>
          </ul>
        </div>
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

  attr :id, :string, required: true
  attr :href, :string, default: nil
  attr :navigate, :string, default: nil
  attr :active, :boolean, default: false
  attr :class, :any, default: nil
  attr :on_click, :any, default: nil

  slot :inner_block, required: true

  defp sidebar_item(assigns) do
    assigns =
      assigns
      |> assign(:on_click, assigns.on_click || hide_sidebar())
      |> assign(
        :rest,
        cond do
          assigns.href -> %{href: assigns.href}
          assigns.navigate -> %{navigate: assigns.navigate}
          true -> %{}
        end
      )

    ~H"""
    <.button
      id={@id}
      variant="ghost"
      size="md"
      type="button"
      aria-current={@active && "page"}
      selected={@active}
      class={["min-h-touch-target w-full justify-start overflow-hidden text-left font-medium", @class]}
      phx-click={@on_click}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.button>
    """
  end

  attr :current_path, :string, required: true

  defp admin_links(assigns) do
    ~H"""
    <li>
      <.sidebar_item
        id="sidebar-admin-instance-settings-link"
        navigate={~p"/admin/settings"}
        active={active?(@current_path, "/admin/settings")}
      >
        <Lucideicons.settings_2 />
        <span class="min-w-0 flex-1 truncate">{dgettext("nav", "Instance settings")}</span>
      </.sidebar_item>
    </li>
    <li>
      <.sidebar_item
        id="sidebar-admin-media-browser-link"
        navigate={~p"/admin/media"}
        active={
          active?(@current_path, "/admin/media") and
            not String.starts_with?(@current_path, "/admin/media/sources")
        }
      >
        <Lucideicons.film />
        <span class="min-w-0 flex-1 truncate">{dgettext("nav", "Media browser")}</span>
      </.sidebar_item>
    </li>
    <li>
      <.sidebar_item
        id="sidebar-admin-media-sources-link"
        navigate={~p"/admin/media/sources"}
        active={active?(@current_path, "/admin/media/sources")}
      >
        <Lucideicons.folder_input />
        <span class="min-w-0 flex-1 truncate">{dgettext("nav", "Media Sources")}</span>
      </.sidebar_item>
    </li>
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
      |> assign(:libraries, assigns.membership.club.libraries)
      |> assign(:active, active?(assigns.current_path, url))

    ~H"""
    <%!--
      Align the submenu rail with the center of the club avatar:
      club row left padding (space.group) + half the avatar size (2rem / 2).
    --%>
    <li class={[
      "flex flex-col gap-tight",
      "[--club-nav-avatar-size:2rem]",
      "[--club-nav-rail-offset:calc(var(--wc-space-group)_+_(var(--club-nav-avatar-size)_/_2))]"
    ]}>
      <div class={[
        "flex min-h-touch-target items-center overflow-hidden rounded-control border border-transparent transition-colors duration-150",
        @active && "bg-surface-selected text-text",
        !@active &&
          "text-text-muted hover:bg-surface-hover hover:text-text active:bg-surface-active focus-within:bg-surface-hover focus-within:text-text"
      ]}>
        <.link
          id={"club-nav-link-#{@membership.club.id}"}
          navigate={@url}
          aria-current={@active && "page"}
          class="flex min-h-touch-target min-w-0 flex-1 items-center gap-related px-group text-left text-sm font-semibold text-inherit transition-colors outline-none [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-icon"
          phx-click={hide_sidebar()}
        >
          <.avatar id={@membership.club.id} name={@membership.club.name} size="md" />
          <span class="min-w-0 flex-1 truncate">{@membership.club.name}</span>
        </.link>

        <.dropdown_menu id={"club-nav-actions-#{@membership.club.id}"} class="shrink-0 pr-tight">
          <:trigger>
            <button
              id={"club-nav-actions-trigger-#{@membership.club.id}"}
              type="button"
              aria-label={dgettext("nav", "Club actions")}
              data-club-nav-actions
              class={[
                "inline-flex size-control-sm shrink-0 items-center justify-center rounded-control text-inherit transition-colors outline-none focus-visible:ring-2 focus-visible:ring-focus-ring [&_svg]:size-icon-sm",
                @active &&
                  "hover:bg-surface-hover hover:text-text active:bg-surface-active focus-visible:bg-surface-hover focus-visible:text-text",
                !@active &&
                  "hover:bg-surface-active hover:text-text active:bg-surface-active focus-visible:bg-surface-active focus-visible:text-text"
              ]}
            >
              <Lucideicons.ellipsis_vertical />
            </button>
          </:trigger>

          <.dropdown_menu_item
            :if={@membership.role == :admin}
            id={"club-nav-members-link-#{@membership.club.id}"}
            navigate={"#{@url}/members"}
            phx-click={hide_sidebar()}
          >
            <Lucideicons.user />{dgettext("clubs", "Manage members")}
          </.dropdown_menu_item>
          <.dropdown_menu_item
            :if={@membership.role == :admin}
            id={"club-nav-settings-link-#{@membership.club.id}"}
            navigate={"#{@url}/settings"}
            phx-click={hide_sidebar()}
          >
            <Lucideicons.settings />{dgettext("clubs", "Club Settings")}
          </.dropdown_menu_item>
          <.dropdown_menu_separator :if={@membership.role == :admin} />
          <.dropdown_menu_item
            :if={@membership.role == :admin}
            id={"club-nav-delete-club-button-#{@membership.club.id}"}
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
            id={"club-nav-leave-club-button-#{@membership.id}"}
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
      </div>

      <ul
        :if={@libraries != []}
        class="ml-[var(--club-nav-rail-offset)] flex list-none flex-col gap-tight border-l border-border-subtle py-tight pl-related"
      >
        <.library_nav_item
          :for={library <- @libraries}
          library={library}
          current_path={@current_path}
        />
      </ul>
    </li>
    """
  end

  attr :library, Library, required: true
  attr :current_path, :string, required: true

  defp library_nav_item(assigns) do
    url = ~p"/clubs/#{assigns.library.club_id}/libraries/#{assigns.library.id}"

    assigns =
      assigns
      |> assign(:url, url)
      |> assign(:active, active?(assigns.current_path, url))

    ~H"""
    <li>
      <.sidebar_item id={"sidebar-library-link-#{@library.id}"} navigate={@url} active={@active}>
        <.library_icon library={@library} />
        <span class="min-w-0 flex-1 truncate">{@library.name}</span>
      </.sidebar_item>
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
    %{create_club_form: form} = socket.assigns

    case AshPhoenix.Form.submit(form, params: params, read_one?: true) do
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
