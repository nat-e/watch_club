defmodule WatchClubWeb.Live.Admin.UsersPage.UsersTable do
  use WatchClubWeb, :component

  alias WatchClubWeb.Helpers.Time

  attr :users, :list, required: true
  attr :current_user, User, required: true

  def users_table(assigns) do
    ~H"""
    <.table class="@container/table">
      <.table_header>
        <.table_row>
          <.table_head class="w-full max-w-0 text-left">
            {dgettext("admin_users", "User")}
          </.table_head>
          <.table_head class="text-left">{dgettext("admin_users", "Clubs")}</.table_head>
          <.table_head class="@max-2xl:hidden text-left">
            {dgettext("admin_users", "Member since")}
          </.table_head>
          <.table_head class="text-right">
            <span class="sr-only">{dgettext("admin_users", "Actions")}</span>
          </.table_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.user_row
          :for={user <- @users}
          user={user}
          locale={@current_user.settings.locale}
        />
      </.table_body>
    </.table>
    """
  end

  attr :user, User, required: true
  attr :locale, :atom, required: true

  defp user_row(assigns) do
    assigns = assigns |> assign(:clubs, Enum.map(assigns.user.memberships, & &1.club))

    ~H"""
    <.table_row>
      <.table_cell class="w-full text-left">
        <.inline space="related">
          <.avatar id={@user.id} name={@user.username} />
          <span class="truncate font-bold">{@user.username}</span>
        </.inline>
      </.table_cell>
      <.table_cell class="text-left">
        <.avatar_group :if={!@user.administrator?} avatars={@clubs} />
        <.badge :if={@user.administrator?} variant="accent">
          <:icon><Lucideicons.shield /></:icon>
          {dgettext("admin_users", "Instance Admin")}
        </.badge>
      </.table_cell>
      <.table_cell class="hidden @2xl:table-cell text-left">
        <span class="text-text-muted">{Time.relative_from_now(@user.inserted_at, @locale)}</span>
      </.table_cell>
      <.table_cell class="text-right">
        <.user_actions user={@user} />
      </.table_cell>
    </.table_row>
    """
  end

  attr :user, User, required: true

  defp user_actions(assigns) do
    ~H"""
    <.dropdown_menu
      :if={!@user.administrator?}
      id={"user-actions-#{@user.id}"}
    >
      <:trigger>
        <.button
          id={"user-actions-trigger-#{@user.id}"}
          size="icon"
          variant="secondary"
          aria-label={dgettext("admin_users", "Actions for %{username}", username: @user.username)}
        >
          <Lucideicons.ellipsis_vertical />
        </.button>
      </:trigger>
      <.dropdown_menu_item
        :if={!@user.administrator?}
        id={"delete-user-#{@user.id}"}
        variant="destructive"
        phx-click="open_delete_user_modal"
        phx-value-id={@user.id}
      >
        <Lucideicons.trash_2 /> {dgettext("admin_users", "Delete user")}
      </.dropdown_menu_item>
    </.dropdown_menu>
    """
  end
end
