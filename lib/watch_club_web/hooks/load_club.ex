defmodule WatchClubWeb.Hooks.LoadClub do
  @moduledoc """
  A LiveView hook that loads a club from a `club_id` URL parameter in a `:club` assign on the socket.
  If the club is not available for the User, they will be redirected to the home page.
  Set admin_only to true to enforce the user is an admin of the club.
  """
  use WatchClubWeb, :verified_routes
  use Gettext, backend: WatchClubWeb.Gettext

  import Phoenix.LiveView
  import Phoenix.Component

  alias WatchClub.Clubs
  alias WatchClub.Clubs.Membership

  require Logger

  @spec on_mount(boolean(), any(), any(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(admin_only, %{"club_id" => club_id}, _session, socket) do
    with %Membership{} = membership <-
           socket.assigns.current_user.memberships |> Enum.find(&(&1.club_id == club_id)),
         true <- !admin_only || membership.role == :admin,
         {:ok, club} <- Clubs.get_club_by_id(club_id, actor: socket.assigns.current_user) do
      {:cont, socket |> assign(:club, club)}
    else
      error ->
        Logger.warning("Error loading club: #{inspect(error)}")

        {:halt,
         socket
         |> put_flash(
           :error,
           dgettext("clubs", "The page you were looking for does not exist")
         )
         |> push_navigate(to: ~p"/")}
    end
  end
end
