defmodule WatchClubWeb.Components.Navigation.Sidebar do
  @moduledoc """
  The navigation on desktop: Home, My Requests, the user's clubs with their libraries, their lists
  and the account menu.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Libraries.LibraryIcon
  import WatchClubWeb.Components.Navigation.AccountMenu

  alias WatchClubWeb.Components.Clubs.ClubDialogsLive
  alias WatchClubWeb.Components.Lists.ListDialogsLive

  attr :current_path, :string, required: true

  attr :current_user, User,
    required: true,
    doc: "with their memberships, the clubs' libraries and their lists"

  attr :instance_settings, InstanceSettings, required: true

  def sidebar(assigns) do
    ~H"""
    <aside
      id="sidebar"
      class="fixed inset-y-0 left-0 z-20 hidden w-(--wc-sidebar-width) flex-col bg-surface text-text md:flex"
    >
      <header class="flex h-row-lg shrink-0 items-center pr-related pl-group">
        <.link
          id="sidebar-instance-link"
          navigate={~p"/"}
          class="min-w-0 truncate rounded-control font-heading text-base font-semibold"
        >
          {@instance_settings.name}
        </.link>
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
              active={@current_path == ~p"/"}
              label={dgettext("nav", "Home")}
            >
              <Lucideicons.home />
            </.sidebar_item>
          </li>
          <li>
            <.sidebar_item
              id="sidebar-my-requests-link"
              navigate={~p"/my-requests"}
              active={@current_path == ~p"/my-requests"}
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
          on_create={if @current_user.administrator?, do: ClubDialogsLive.open_create_club_modal()}
        >
          <%!-- A user's clubs are intentionally few, so they are a plain list --%>
          <ul class="flex list-none flex-col gap-related p-0">
            <.club_nav_item
              :for={membership <- @current_user.memberships}
              membership={membership}
              current_path={@current_path}
            />
          </ul>
        </.sidebar_section>

        <.sidebar_section
          id="sidebar-lists"
          title={dgettext("nav", "Lists")}
          create_label={dgettext("nav", "New list")}
          on_create={ListDialogsLive.open_create_list_modal()}
        >
          <%!-- A user's lists are intentionally few, so they are a plain list --%>
          <ul class="flex list-none flex-col gap-px p-0">
            <.list_nav_item
              :for={list <- @current_user.lists}
              list={list}
              current_path={@current_path}
            />
          </ul>
        </.sidebar_section>
      </nav>

      <div class="shrink-0 border-t border-border-subtle p-related">
        <.account_menu id="sidebar-account-menu" user={@current_user} />
      </div>
    </aside>
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

  defp club_nav_item(assigns) do
    url = Url.club_link(assigns.membership.club)

    assigns =
      assigns
      |> assign(:url, url)
      |> assign(:libraries, assigns.membership.club.libraries)
      |> assign(
        :active,
        Url.in_section?(assigns.current_path, url) and
          not Enum.any?(
            assigns.membership.club.libraries,
            &Url.in_section?(assigns.current_path, Url.club_library_link(&1))
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
          >
            <Lucideicons.user />{dgettext("clubs", "Manage members")}
          </.dropdown_menu_item>
          <.dropdown_menu_item
            :if={@membership.role == :admin}
            id={"club-nav-settings-link-#{@membership.club.id}"}
            navigate={~p"/clubs/#{@membership.club.id}/settings"}
          >
            <Lucideicons.settings />{dgettext("clubs", "Club Settings")}
          </.dropdown_menu_item>
          <.dropdown_menu_separator :if={@membership.role == :admin} />
          <.dropdown_menu_item
            :if={@membership.role == :admin}
            id={"club-nav-delete-club-button-#{@membership.club.id}"}
            phx-click={ClubDialogsLive.open_delete_club_modal(@membership.club)}
            variant="destructive"
          >
            <Lucideicons.trash />{dgettext("clubs", "Delete club")}
          </.dropdown_menu_item>
          <.dropdown_menu_item
            :if={@membership.role == :member}
            id={"club-nav-leave-club-button-#{@membership.id}"}
            phx-click={ClubDialogsLive.open_leave_club_modal(@membership)}
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
      |> assign(:active, Url.in_section?(assigns.current_path, url))

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

  defp list_nav_item(assigns) do
    url = Url.list_link(assigns.list.id)

    assigns =
      assigns
      |> assign(:url, url)
      |> assign(:active, Url.in_section?(assigns.current_path, url))

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
            phx-click={ListDialogsLive.open_edit_list_modal(@list)}
          >
            <Lucideicons.pencil />{dgettext("lists", "Edit list")}
          </.dropdown_menu_item>
          <.dropdown_menu_item
            id={"list-nav-delete-button-#{@list.id}"}
            variant="destructive"
            phx-click={ListDialogsLive.open_delete_list_modal(@list)}
          >
            <Lucideicons.trash />{dgettext("lists", "Delete list")}
          </.dropdown_menu_item>
        </:menu>
      </.sidebar_item>
    </li>
    """
  end
end
