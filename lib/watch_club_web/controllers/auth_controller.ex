defmodule WatchClubWeb.AuthController do
  use WatchClubWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    message =
      case activity do
        {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
        {:password, :reset} -> "Your password has successfully been reset"
        _ -> "You are now signed in"
      end

    conn =
      conn
      |> delete_session(:return_to)
      |> store_in_session(user)
      # If your resource has a different name, update the assign name here (i.e :current_admin)
      |> assign(:current_user, user)

    conn =
      if Phoenix.Flash.get(conn.assigns.flash, :success) do
        conn
      else
        put_flash(conn, :info, message)
      end

    redirect(conn, to: return_to)
  end

  def failure(conn, activity, reason) do
    message =
      case {activity, reason} do
        {_,
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Forbidden{
             errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
           }
         }} ->
          """
          You have already signed in another way, but have not confirmed your account.
          You can confirm your account using the link we sent to you, or by resetting your password.
          """

        _ ->
          "Incorrect username or password"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/sign-in"

    conn
    |> clear_session(:watch_club)
    |> redirect(to: return_to)
  end
end
