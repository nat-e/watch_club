defmodule WatchClubWeb.Live.Clubs.Members.MembersTable do
  use WatchClubWeb, :component

  alias WatchClub.Accounts.User
  alias WatchClubWeb.Helpers.Url

  attr :memberships, :list, required: true
  attr :current_user, User, required: true
  attr :current_url, Url, required: true

  def members_table(assigns) do
    ~H"""
    <.table class="@container/table">
      <.table_header>
        <.table_row>
          <.table_head class="text-left">{dgettext("clubs", "User")}</.table_head>
          <.table_head>{dgettext("clubs", "Role")}</.table_head>
          <.table_head class="@max-xl:hidden">{dgettext("clubs", "Member since")}</.table_head>
          <.table_head class="text-right"></.table_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.member_row
          :for={membership <- @memberships}
          membership={membership}
          current_url={@current_url}
          current_user={@current_user}
        />
      </.table_body>
    </.table>
    """
  end

  defp member_row(assigns) do
    ~H"""
    <.table_row>
      <.table_cell class="text-left">
        <.inline class="font-bold">
          <.avatar id={@membership.user.id} name={@membership.user.username} />
          {@membership.user.username}
        </.inline>
      </.table_cell>
      <.table_cell>
        <.role_badge role={@membership.role} />
      </.table_cell>
      <.table_cell class="@max-xl:hidden">
        {WatchClubWeb.Helpers.Time.relative_from_now(
          @membership.inserted_at,
          @current_user.settings.locale
        )}
      </.table_cell>
      <.table_cell class="text-right">
        <.dropdown_menu
          :if={@membership.user_id != @current_user.id}
          id={"member-actions-#{@membership.id}"}
        >
          <:trigger>
            <.button id={"member-actions-trigger-#{@membership.id}"} size="icon" variant="secondary">
              <Lucideicons.ellipsis_vertical />
            </.button>
          </:trigger>
          <.dropdown_menu_item
            :if={@membership.user_id != @current_user.id}
            id={"remove-member-menu-item-#{@membership.id}"}
            variant="destructive"
            phx-click="open_remove_member_modal"
            phx-value-membership_id={@membership.id}
          >
            <Lucideicons.trash_2 />{dgettext("clubs", "Remove member")}
          </.dropdown_menu_item>
        </.dropdown_menu>
      </.table_cell>
    </.table_row>
    """
  end

  attr :role, :atom, required: true

  defp role_badge(%{role: :admin} = assigns) do
    ~H"""
    <.badge variant="accent">{dgettext("clubs", "Admin")}</.badge>
    """
  end

  defp role_badge(%{role: :member} = assigns) do
    ~H"""
    <.badge variant="secondary">{dgettext("clubs", "Member")}</.badge>
    """
  end
end
