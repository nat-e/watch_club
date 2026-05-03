defmodule WatchClubWeb.Components.Nav do
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Clubs

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
      <:action :if={@membership.role == :admin}>
        <.dropdown_menu>
          <:trigger>
            <.button size="icon-sm" variant="ghost"><Lucideicons.ellipsis_vertical /></.button>
          </:trigger>
          <.dropdown_menu_item patch={
            @current_url
            |> Url.add_param(
              WatchClubWeb.Modals.CreateInvitation.modal_name(),
              assigns.membership.club.id
            )
            |> Url.to_url()
          }>
            <Lucideicons.user />Invite members
          </.dropdown_menu_item>
          <.dropdown_menu_item href={"#{@url}/settings"}>
            <Lucideicons.settings />Club Settings
          </.dropdown_menu_item>
          <.dropdown_menu_separator />
          <.dropdown_menu_item
            patch={
              @current_url
              |> Url.add_param(
                WatchClubWeb.Modals.DeleteClub.modal_name(),
                assigns.membership.club.id
              )
              |> Url.to_url()
            }
            variant="destructive"
          >
            <Lucideicons.trash />Delete club
          </.dropdown_menu_item>
        </.dropdown_menu>
      </:action>
      <:icon>
        <.club_avatar club={@membership.club} />
      </:icon>
      {@membership.club.name}
    </.sidebar_menu_item>
    """
  end
end
