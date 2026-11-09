defmodule WatchClubWeb.Hooks.Auth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use WatchClubWeb, :verified_routes

  alias AshAuthentication.Phoenix.LiveSession

  # What the navigation shows of the current user, such as the Inbox and Requests tabs' counts
  @navigation_resources [
    WatchClub.Accounts.UserSettings,
    WatchClub.Conversations.Message,
    WatchClub.Conversations.Participant,
    WatchClub.Playlists.PlaylistAccess,
    WatchClub.Requests.RequestSubscriber
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
      {:halt, redirect_to_sign_in(socket)}
    end
  end

  def on_mount(:live_administrator_required, _params, _session, socket) do
    user = socket.assigns[:current_user]

    cond do
      is_nil(user) ->
        {:halt, redirect_to_sign_in(socket)}

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

  # The sign-in page sends the user back to the page they asked for. Only the first, disconnected
  # render knows that page: a socket that reconnects without a user goes to the default page.
  defp redirect_to_sign_in(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :uri) do
      %URI{path: path, query: ""} ->
        Phoenix.LiveView.redirect(socket, to: ~p"/sign-in?#{[return_to: path]}")

      %URI{path: path, query: query} ->
        Phoenix.LiveView.redirect(socket, to: ~p"/sign-in?#{[return_to: path <> "?" <> query]}")

      nil ->
        Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")
    end
  end

  defp subscribe_to_current_user_pubsub(socket, user) do
    WatchClub.PubSub.subscribe_if_connected(
      socket,
      "user:#{user.id}"
    )

    socket
    |> Phoenix.LiveView.attach_hook(
      :reload_user_on_change,
      :handle_info,
      &reload_user_on_change/2
    )
  end

  # A bulk action sends one notification per record, such as opening My Requests: the user
  # reloads once, after the notifications already received
  defp reload_user_on_change(%Ash.Notifier.Notification{resource: resource}, socket)
       when resource in @navigation_resources do
    if !socket.private[:reload_user_pending?], do: send(self(), :reload_user)
    {:cont, Phoenix.LiveView.put_private(socket, :reload_user_pending?, true)}
  end

  defp reload_user_on_change(:reload_user, socket) do
    user = WatchClub.Accounts.get_current_user!(actor: socket.assigns.current_user)

    {:halt,
     socket
     |> assign(:current_user, user)
     |> Phoenix.LiveView.put_private(:reload_user_pending?, false)}
  end

  defp reload_user_on_change(_msg, socket) do
    {:cont, socket}
  end
end
