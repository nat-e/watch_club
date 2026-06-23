defmodule WatchClubWeb.Hooks.Auth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use WatchClubWeb, :verified_routes

  alias AshAuthentication.Phoenix.LiveSession

  @sidebar_resources [
    WatchClub.Accounts.UserSettings,
    WatchClub.Clubs.Membership,
    WatchClub.Clubs.Club,
    WatchClub.Clubs.Library
  ]

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {WatchClubWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    {:cont, LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user do
      {:cont, socket |> subscribe_to_current_user_pubsub(user)}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user do
      {:cont, socket |> subscribe_to_current_user_pubsub(user)}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_administrator_required, _params, _session, socket) do
    user = socket.assigns[:current_user]

    cond do
      is_nil(user) ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}

      user.administrator? ->
        {:cont, socket |> subscribe_to_current_user_pubsub(user)}

      true ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  defp subscribe_to_current_user_pubsub(socket, user) do
    WatchClub.PubSub.subscribe_if_connected(
      socket,
      ["user:#{user.id}" | Enum.map(user.memberships, &"club:#{&1.club.id}")]
    )

    socket
    |> Phoenix.LiveView.attach_hook(
      :reload_user_on_change,
      :handle_info,
      &reload_user_on_change/2
    )
  end

  defp reload_user_on_change(%Ash.Notifier.Notification{resource: resource}, socket)
       when resource in @sidebar_resources do
    user = WatchClub.Accounts.get_current_user!(actor: socket.assigns.current_user)
    {:cont, socket |> assign(:current_user, user)}
  end

  defp reload_user_on_change(_msg, socket) do
    {:cont, socket}
  end
end
