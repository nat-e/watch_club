defmodule WatchClubWeb.Components.Navigation.SidebarLive do
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Libraries.LibraryIcon
  import WatchClubWeb.Components.Navigation.Sidebar.CreateClubModal
  import WatchClubWeb.Components.Navigation.Sidebar.CreateOrEditListModal
  import WatchClubWeb.Components.Navigation.Sidebar.DeleteClubModal
  import WatchClubWeb.Components.Navigation.Sidebar.DeleteListModal
  import WatchClubWeb.Components.Navigation.Sidebar.LeaveClubModal

  alias WatchClubWeb.Components.UI.IconPickerLive

  @sidebar_transition_time 200

  def dom_id, do: "sidebar-shell"

  def show_sidebar(js \\ %JS{}) do
    js
    |> JS.remove_class("invisible pointer-events-none", to: "#sidebar-backdrop")
    |> JS.remove_class("opacity-0", to: "#sidebar-backdrop")
    |> JS.remove_class("-translate-x-full", to: "#sidebar-panel")
    |> JS.focus(to: "#sidebar-close-button")
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
    <div id={dom_id()} phx-window-keydown={hide_sidebar()} phx-key="escape">
      <button
        id="sidebar-backdrop"
        type="button"
        aria-label={dgettext("nav", "Close navigation")}
        class="invisible fixed inset-0 z-40 pointer-events-none bg-scrim opacity-0 backdrop-blur-sm transition-opacity duration-200 ease-out md:hidden"
        phx-click={hide_sidebar()}
      />

      <aside
        id="sidebar-panel"
        class="fixed inset-y-0 left-0 z-50 flex w-[min(85vw,var(--wc-sidebar-width))] -translate-x-full flex-col bg-surface text-text shadow-overlay transition-transform duration-200 ease-out will-change-transform md:z-20 md:w-(--wc-sidebar-width) md:translate-x-0 md:shadow-none"
      >
        <header class="flex h-row-lg shrink-0 items-center gap-related pr-related pl-group">
          <.link
            id="sidebar-instance-link"
            navigate={~p"/"}
            class="flex min-w-0 items-center gap-related"
            phx-click={hide_sidebar()}
          >
            <span class="flex size-control-sm shrink-0 items-center justify-center rounded-control bg-primary-bg text-primary">
              <Lucideicons.popcorn class="size-icon-sm" />
            </span>
            <span class="truncate font-heading text-base font-semibold">
              {@instance_settings.name}
            </span>
          </.link>
          <.button
            id="sidebar-close-button"
            variant="ghost"
            size="icon-sm"
            class="ml-auto md:hidden pointer-coarse:size-touch-target!"
            aria-label={dgettext("nav", "Close navigation")}
            phx-click={hide_sidebar()}
          >
            <Lucideicons.x />
          </.button>
        </header>

        <nav
          aria-label={dgettext("nav", "Main navigation")}
          class="flex flex-1 flex-col gap-cluster overflow-y-auto px-related pt-related pb-group"
        >
          <ul class="flex list-none flex-col gap-px p-0">
            <li>
              <.sidebar_item
                id="sidebar-home-link"
                navigate={~p"/"}
                active={active?(@current_path, "/")}
                label={dgettext("nav", "Home")}
              >
                <Lucideicons.home />
              </.sidebar_item>
            </li>
            <li>
              <.sidebar_item
                id="sidebar-my-requests-link"
                navigate={~p"/my-requests"}
                active={active?(@current_path, "/my-requests")}
                label={dgettext("nav", "My Requests")}
              >
                <Lucideicons.inbox />
              </.sidebar_item>
            </li>
          </ul>

          <.sidebar_section
            :if={@current_user.memberships != [] or @current_user.administrator?}
            id="sidebar-clubs"
            title={dgettext("nav", "Clubs")}
            create_label={dgettext("nav", "New club")}
            on_create={
              if @current_user.administrator?,
                do: JS.push("open_create_club_modal", target: @myself) |> hide_sidebar()
            }
          >
            <%!-- A user's clubs are intentionally few, so they are a plain list --%>
            <ul class="flex list-none flex-col gap-related p-0">
              <.club_nav_item
                :for={membership <- @current_user.memberships}
                membership={membership}
                current_path={@current_path}
                myself={@myself}
              />
            </ul>
          </.sidebar_section>

          <.sidebar_section
            id="sidebar-lists"
            title={dgettext("nav", "Lists")}
            create_label={dgettext("nav", "New list")}
            on_create={JS.push("open_create_list_modal", target: @myself) |> hide_sidebar()}
          >
            <%!-- A user's lists are intentionally few, so they are a plain list --%>
            <ul class="flex list-none flex-col gap-px p-0">
              <.list_nav_item
                :for={list <- @current_user.lists}
                list={list}
                current_path={@current_path}
                myself={@myself}
              />
            </ul>
          </.sidebar_section>
        </nav>

        <div class="shrink-0 border-t border-border-subtle p-related">
          <.user_menu user={@current_user} />
        </div>
      </aside>

      <.create_club_modal :if={@create_club_form} form={@create_club_form} myself={@myself} />
      <.delete_club_modal :if={@club_to_delete} club={@club_to_delete} myself={@myself} />
      <.leave_club_modal
        :if={@membership_to_leave}
        membership={@membership_to_leave}
        myself={@myself}
      />

      <.create_or_edit_list_modal
        :if={@list_form}
        form={@list_form}
        icon={@list_icon}
        myself={@myself}
      />
      <.delete_list_modal :if={@list_to_delete} list={@list_to_delete} myself={@myself} />
      <.live_component
        :if={@list_icon_picker_open}
        module={IconPickerLive}
        id="sidebar-list-icon-picker"
        selected_icon={@list_icon}
        title={dgettext("lists", "Choose an icon")}
        description={dgettext("lists", "Select an icon for your list")}
        on_select={JS.push("list_icon_selected", target: @myself)}
        on_close={JS.push("close_list_icon_picker", target: @myself)}
      />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :create_label, :string, required: true
  attr :on_create, JS, default: nil, doc: "shows a create button in the heading"

  slot :inner_block, required: true

  defp sidebar_section(assigns) do
    ~H"""
    <div class="flex flex-col gap-tight">
      <div class="flex min-h-control-sm items-center justify-between pl-related">
        <h2 class="text-xs">
          <.text_label text={@title} />
        </h2>
        <.button
          :if={@on_create}
          id={"#{@id}-create-button"}
          variant="ghost"
          size="icon-sm"
          class="pointer-coarse:size-touch-target!"
          aria-label={@create_label}
          phx-click={@on_create}
        >
          <Lucideicons.plus />
        </.button>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :user, User, required: true

  defp user_menu(assigns) do
    ~H"""
    <.dropdown_menu id="sidebar-user-menu" class="w-full">
      <:trigger>
        <button
          id="sidebar-user-menu-button"
          type="button"
          class="flex w-full items-center gap-related rounded-control p-related text-left transition-colors hover:bg-surface-hover aria-expanded:bg-surface-hover"
        >
          <.avatar id={@user.id} name={@user.username} size="md" aria-hidden="true" />
          <span class="flex min-w-0 flex-1 flex-col">
            <span class="truncate text-sm font-semibold">{@user.username}</span>
            <span :if={@user.administrator?} class="truncate text-xs text-text-muted">
              {dgettext("nav", "Instance administrator")}
            </span>
          </span>
          <Lucideicons.chevrons_up_down class="size-icon-sm shrink-0 text-text-subtle" />
        </button>
      </:trigger>

      <%!-- Repeats the trigger, so screen readers skip it --%>
      <div class="flex w-56 items-center gap-related p-related" aria-hidden="true">
        <.avatar id={@user.id} name={@user.username} size="md" />
        <div class="flex min-w-0 flex-col">
          <span class="truncate text-sm font-semibold">{@user.username}</span>
          <span :if={@user.administrator?} class="truncate text-xs text-text-muted">
            {dgettext("nav", "Instance administrator")}
          </span>
        </div>
      </div>
      <.dropdown_menu_separator />
      <.dropdown_menu_item
        id="sidebar-settings-link"
        navigate={~p"/settings"}
        phx-click={hide_sidebar()}
      >
        <Lucideicons.settings />{dgettext("nav", "Settings")}
      </.dropdown_menu_item>
      <div
        :if={@user.administrator?}
        role="group"
        aria-labelledby="sidebar-user-menu-administration-title"
      >
        <.dropdown_menu_separator />
        <p id="sidebar-user-menu-administration-title" class="px-related pt-related pb-tight text-xs">
          <.text_label text={dgettext("nav", "Administration")} />
        </p>
        <.dropdown_menu_item
          id="sidebar-admin-instance-settings-link"
          navigate={~p"/admin/settings"}
          phx-click={hide_sidebar()}
        >
          <Lucideicons.settings_2 />
          {dgettext("nav", "Instance settings")}
        </.dropdown_menu_item>
        <.dropdown_menu_item
          id="sidebar-admin-users-link"
          navigate={~p"/admin/users"}
          phx-click={hide_sidebar()}
        >
          <Lucideicons.users />{dgettext("nav", "Users")}
        </.dropdown_menu_item>
        <.dropdown_menu_item
          id="sidebar-admin-media-browser-link"
          navigate={~p"/admin/media"}
          phx-click={hide_sidebar()}
        >
          <Lucideicons.film />{dgettext("nav", "Media browser")}
        </.dropdown_menu_item>
        <.dropdown_menu_item
          id="sidebar-admin-media-sources-link"
          navigate={~p"/admin/media/sources"}
          phx-click={hide_sidebar()}
        >
          <Lucideicons.folder_input />
          {dgettext("nav", "Media Sources")}
        </.dropdown_menu_item>
      </div>
      <.dropdown_menu_separator />
      <.dropdown_menu_item id="sidebar-sign-out-link" href={~p"/sign-out"} method="delete">
        <Lucideicons.log_out />{dgettext("nav", "Sign out")}
      </.dropdown_menu_item>
    </.dropdown_menu>
    """
  end

  attr :id, :string, required: true
  attr :navigate, :string, required: true
  attr :active, :boolean, default: false

  attr :nested, :boolean,
    default: false,
    doc: "a library row under its club: normal weight, its icon lined up with the club name"

  attr :label, :string, required: true

  slot :inner_block, required: true, doc: "the leading icon or avatar"

  slot :menu, doc: "dropdown menu items, behind a button at the end of the row" do
    attr :label, :string, required: true, doc: "the accessible name of the menu button"
  end

  defp sidebar_item(assigns) do
    ~H"""
    <div class={[
      "group/item flex items-center rounded-control transition-colors",
      @active && "bg-surface-selected",
      !@active && "hover:bg-surface-hover has-aria-expanded:bg-surface-hover"
    ]}>
      <%!--
        pl-8 lines a library icon up with its club's name:
        the row's padding (space.related) + the club avatar (size-4) + the gap (space.related).
      --%>
      <.link
        id={@id}
        navigate={@navigate}
        aria-current={@active && "page"}
        class={[
          "flex min-h-touch-target min-w-0 flex-1 items-center gap-related rounded-control pr-related text-sm pointer-fine:min-h-9",
          "[&_svg]:size-icon-sm [&_svg]:shrink-0",
          @nested && "pl-8",
          !@nested && "pl-related font-semibold",
          @active && "text-text [&_svg]:text-text-muted",
          !@active && "text-text-muted group-hover/item:text-text [&_svg]:text-text-subtle"
        ]}
        phx-click={hide_sidebar()}
      >
        {render_slot(@inner_block)}
        <span class="min-w-0 flex-1 truncate">{@label}</span>
      </.link>
      <%!-- Shown on hover, focus or while open, and always on screens that can't hover --%>
      <.dropdown_menu
        :for={menu <- @menu}
        id={"#{@id}-menu"}
        class="shrink-0 opacity-0 transition-opacity group-hover/item:opacity-100 group-focus-within/item:opacity-100 has-aria-expanded:opacity-100 [@media(hover:none)]:opacity-100"
      >
        <:trigger>
          <.button
            id={"#{@id}-menu-button"}
            variant="ghost"
            size="icon-sm"
            class="hover:bg-transparent! active:bg-transparent! pointer-coarse:size-touch-target!"
            aria-label={menu.label}
          >
            <Lucideicons.ellipsis_vertical />
          </.button>
        </:trigger>
        {render_slot(menu)}
      </.dropdown_menu>
    </div>
    """
  end

  attr :membership, Membership, required: true
  attr :current_path, :string, required: true
  attr :myself, :any, required: true

  defp club_nav_item(assigns) do
    url = ~p"/clubs/#{assigns.membership.club.id}"

    assigns =
      assigns
      |> assign(:url, url)
      |> assign(:libraries, assigns.membership.club.libraries)
      |> assign(
        :active,
        active?(assigns.current_path, url) and
          not Enum.any?(
            assigns.membership.club.libraries,
            &active?(assigns.current_path, Url.club_library_link(&1))
          )
      )

    ~H"""
    <li class="flex flex-col gap-px">
      <.sidebar_item
        id={"club-nav-link-#{@membership.club.id}"}
        navigate={@url}
        active={@active}
        label={@membership.club.name}
      >
        <.avatar
          id={@membership.club.id}
          name={@membership.club.name}
          size="xs"
          aria-hidden="true"
        />

        <:menu label={dgettext("nav", "Actions for %{name}", name: @membership.club.name)}>
          <.dropdown_menu_item
            :if={@membership.role == :admin}
            id={"club-nav-members-link-#{@membership.club.id}"}
            navigate={~p"/clubs/#{@membership.club.id}/members"}
            phx-click={hide_sidebar()}
          >
            <Lucideicons.user />{dgettext("clubs", "Manage members")}
          </.dropdown_menu_item>
          <.dropdown_menu_item
            :if={@membership.role == :admin}
            id={"club-nav-settings-link-#{@membership.club.id}"}
            navigate={~p"/clubs/#{@membership.club.id}/settings"}
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
        </:menu>
      </.sidebar_item>

      <ul :if={@libraries != []} class="flex list-none flex-col gap-px p-0">
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
    url = Url.club_library_link(assigns.library)

    assigns =
      assigns
      |> assign(:url, url)
      |> assign(:active, active?(assigns.current_path, url))

    ~H"""
    <li>
      <.sidebar_item
        id={"sidebar-library-link-#{@library.id}"}
        navigate={@url}
        active={@active}
        label={@library.name}
        nested
      >
        <.library_icon library={@library} />
      </.sidebar_item>
    </li>
    """
  end

  attr :list, ContentList, required: true
  attr :current_path, :string, required: true
  attr :myself, :any, required: true

  defp list_nav_item(assigns) do
    url = Url.list_link(assigns.list.id)

    assigns =
      assigns
      |> assign(:url, url)
      |> assign(:active, active?(assigns.current_path, url))

    ~H"""
    <li>
      <.sidebar_item
        id={"list-nav-link-#{@list.id}"}
        navigate={@url}
        active={@active}
        label={@list.name}
      >
        <.lucide_icon name={@list.icon} />

        <:menu label={dgettext("nav", "Actions for %{name}", name: @list.name)}>
          <.dropdown_menu_item
            id={"list-nav-edit-button-#{@list.id}"}
            phx-click={
              JS.push("open_edit_list_modal", target: @myself, value: %{list_id: @list.id})
              |> hide_sidebar()
            }
          >
            <Lucideicons.pencil />{dgettext("lists", "Edit list")}
          </.dropdown_menu_item>
          <.dropdown_menu_item
            id={"list-nav-delete-button-#{@list.id}"}
            variant="destructive"
            phx-click={
              JS.push("open_delete_list_modal", target: @myself, value: %{list_id: @list.id})
              |> hide_sidebar()
            }
          >
            <Lucideicons.trash />{dgettext("lists", "Delete list")}
          </.dropdown_menu_item>
        </:menu>
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

    Clubs.destroy_club!(club, actor: user)

    WatchClubWeb.Hooks.Flash.send_flash(
      :success,
      dgettext("clubs", "Club %{club_name} deleted", club_name: club.name)
    )

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

    Clubs.leave_club!(membership, actor: user)

    WatchClubWeb.Hooks.Flash.send_flash(
      :success,
      dgettext("clubs", "You left %{club_name}", club_name: membership.club.name)
    )

    {:noreply, socket |> assign(:membership_to_leave, nil)}
  end

  def handle_event("open_create_list_modal", _params, socket) do
    form = Lists.form_to_create_list(actor: socket.assigns.current_user)

    {:noreply, socket |> assign(list_form: to_form(form), list_icon: "list")}
  end

  def handle_event("open_edit_list_modal", %{"list_id" => list_id}, socket) do
    list = Enum.find(socket.assigns.current_user.lists, &(&1.id == list_id))
    form = Lists.form_to_update_list(list, actor: socket.assigns.current_user)

    {:noreply, socket |> assign(list_form: to_form(form), list_icon: list.icon)}
  end

  def handle_event("validate_list_form", %{"form" => params}, socket) do
    {:noreply,
     socket |> assign(:list_form, AshPhoenix.Form.validate(socket.assigns.list_form, params))}
  end

  def handle_event("submit_list_form", %{"form" => params}, socket) do
    form = socket.assigns.list_form
    edit? = form.source.type == :update

    case AshPhoenix.Form.submit(form, params: params, read_one?: true) do
      {:ok, _list} ->
        WatchClubWeb.Hooks.Flash.send_flash(
          :success,
          (edit? && dgettext("lists", "List updated")) || dgettext("lists", "List created")
        )

        {:noreply, socket |> reset_modals()}

      {:error, form} ->
        {:noreply, socket |> assign(:list_form, form)}
    end
  end

  def handle_event("open_list_icon_picker", _params, socket) do
    {:noreply, socket |> assign(:list_icon_picker_open, true)}
  end

  def handle_event("close_list_icon_picker", _params, socket) do
    {:noreply, socket |> assign(:list_icon_picker_open, false)}
  end

  def handle_event("list_icon_selected", %{"icon" => icon}, socket) do
    {:noreply, socket |> assign(list_icon: icon, list_icon_picker_open: false)}
  end

  def handle_event("open_delete_list_modal", %{"list_id" => list_id}, socket) do
    list = Enum.find(socket.assigns.current_user.lists, &(&1.id == list_id))

    {:noreply, socket |> assign(:list_to_delete, list)}
  end

  def handle_event("delete_list", %{"list_id" => list_id}, socket) do
    %{current_user: user} = socket.assigns
    list = Enum.find(user.lists, &(&1.id == list_id))

    Lists.destroy_list!(list, actor: user)

    WatchClubWeb.Hooks.Flash.send_flash(
      :success,
      dgettext("lists", "List %{list_name} deleted", list_name: list.name)
    )

    {:noreply, socket |> assign(:list_to_delete, nil)}
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
    |> assign(:list_form, nil)
    |> assign(:list_to_delete, nil)
    |> assign(:list_icon, nil)
    |> assign(:list_icon_picker_open, false)
  end
end
