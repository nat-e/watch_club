defmodule WatchClubWeb.Live.Nav.Components.Sidebar do
  use WatchClubWeb, :component

  attr :url, :string, required: true
  attr :current_url, Url, required: true

  slot :icon
  slot :inner_block

  def sidebar_nav_button(assigns) do
    assigns = assigns |> assign(:active?, assigns.url == assigns.current_url.path)

    ~H"""
    <.sidebar_menu_item size="lg" href={@url} active={@active?}>
      <:icon>{render_slot(@icon)}</:icon>
      {render_slot(@inner_block)}
    </.sidebar_menu_item>
    """
  end

  attr :current_url, Url, required: true
  attr :membership, Membership, required: true
  attr :myself, :any, required: true

  def sidebar_membership_menu_item(assigns) do
    url = "/clubs/#{assigns.membership.club.id}"

    assigns =
      assigns
      |> assign(:url, url)
      |> assign(:active?, url == assigns.current_url.path)

    ~H"""
    <.sidebar_menu_item
      size="lg"
      href={@url}
      active={@active?}
    >
      <:action>
        <.dropdown_menu>
          <:trigger>
            <.button size="icon-sm" variant="ghost"><Lucideicons.ellipsis_vertical /></.button>
          </:trigger>
          <.admin_dropdown_menu
            :if={@membership.role == :admin}
            membership={@membership}
            current_url={@current_url}
            myself={@myself}
            url={@url}
          />
          <.member_dropdown_menu
            :if={@membership.role == :member}
            membership={@membership}
            current_url={@current_url}
          />
        </.dropdown_menu>
      </:action>
      <:icon>
        <.avatar id={@membership.club.id} name={@membership.club.name} />
      </:icon>
      {@membership.club.name}
    </.sidebar_menu_item>
    """
  end

  defp admin_dropdown_menu(assigns) do
    ~H"""
    <.dropdown_menu_item href={"#{@url}/members"}>
      <Lucideicons.user />{dgettext("clubs", "Manage members")}
    </.dropdown_menu_item>
    <.dropdown_menu_item href={"#{@url}/settings"}>
      <Lucideicons.settings />{dgettext("clubs", "Club Settings")}
    </.dropdown_menu_item>
    <.dropdown_menu_separator />
    <.dropdown_menu_item
      phx-click="open_delete_club_modal"
      phx-target={@myself}
      phx-value-club_id={@membership.club.id}
      variant="destructive"
    >
      <Lucideicons.trash />{dgettext("clubs", "Delete club")}
    </.dropdown_menu_item>
    """
  end

  defp member_dropdown_menu(assigns) do
    ~H"""
    <.dropdown_menu_item
      phx-click="open_leave_club_modal"
      phx-target={@myself}
      phx-value-club_id={@membership.id}
      variant="destructive"
    >
      <Lucideicons.door_open />{dgettext("clubs", "Leave club")}
    </.dropdown_menu_item>
    """
  end
end
