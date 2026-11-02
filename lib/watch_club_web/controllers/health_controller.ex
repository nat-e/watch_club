defmodule WatchClubWeb.HealthController do
  use WatchClubWeb, :controller

  def show(conn, _params), do: send_resp(conn, 200, "ok")
end
