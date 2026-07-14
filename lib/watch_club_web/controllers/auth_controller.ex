defmodule WatchClubWeb.AuthController do
  use WatchClubWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, activity, user, _token) do
    # The query param is user-controlled: redirect/2 only accepts local paths,
    # a tampered value raises instead of redirecting off-site
    return_to = conn.params["return_to"] || get_session(conn, :return_to) || ~p"/"

    message =
      case activity do
        {:password, :reset} -> dgettext("auth", "Your password has successfully been reset")
        _ -> nil
      end

    conn =
      conn
      |> delete_session(:return_to)
      |> store_in_session(user)
      # If your resource has a different name, update the assign name here (i.e :current_admin)
      |> assign(:current_user, user)

    conn =
      if message && !Phoenix.Flash.get(conn.assigns.flash, :success) do
        put_flash(conn, :info, message)
      else
        conn
      end

    redirect(conn, to: return_to)
  end

  def failure(conn, _activity, _reason) do
    conn
    |> clear_flash()
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/sign-in"

    conn
    |> clear_session(:watch_club)
    |> redirect(to: return_to)
  end
end
