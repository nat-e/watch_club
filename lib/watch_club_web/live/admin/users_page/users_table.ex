defmodule WatchClubWeb.Live.Admin.UsersPage.UsersTable do
  use WatchClubWeb, :component

  attr :users, :list, required: true
  attr :current_user, User, required: true

  def users_table(assigns) do
    ~H"""
    <.table class="@container/table">
      <.table_header>
        <.table_row>
          <.table_head class="w-full max-w-0">
            {dgettext("admin_users", "User")}
          </.table_head>
          <.table_head class="@max-2xl:hidden">
            {dgettext("admin_users", "Member since")}
          </.table_head>
          <.table_head class="text-end!">
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
    ~H"""
    <.table_row>
      <.table_cell class="w-full">
        <.inline space="related">
          <.avatar id={@user.id} name={@user.username} />
          <.stack space="tight" class="min-w-0">
            <span class="truncate font-semibold">{@user.username}</span>
            <.badge :if={@user.administrator?} variant="accent" class="w-fit">
              <:icon><Lucideicons.shield /></:icon>
              {dgettext("admin_users", "Instance administrator")}
            </.badge>
          </.stack>
        </.inline>
      </.table_cell>
      <.table_cell class="hidden @2xl:table-cell">
        <span class="text-text-muted">{Time.relative_from_now(@user.inserted_at, @locale)}</span>
      </.table_cell>
      <.table_cell class="text-end!">
        <.user_actions user={@user} />
      </.table_cell>
    </.table_row>
    """
  end

  attr :user, User, required: true

  defp user_actions(assigns) do
    ~H"""
    <.dropdown_menu id={"user-actions-#{@user.id}"}>
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
        id={"reset-password-#{@user.id}"}
        phx-click="generate_password_reset_link"
        phx-value-id={@user.id}
      >
        <Lucideicons.key_round /> {dgettext("admin_users", "Reset password")}
      </.dropdown_menu_item>
      <.dropdown_menu_separator :if={!@user.administrator?} />
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
