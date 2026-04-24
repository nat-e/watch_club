defmodule WatchClubWeb.LandingController do
  use WatchClubWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
