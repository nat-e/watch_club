defmodule WatchClubWeb.HealthController do
  use WatchClubWeb, :controller

  # Answers 503 instead of crashing when the database is down, so a long
  # outage doesn't report an error on every check.
  def show(conn, _params) do
    case WatchClub.Repo.query("SELECT 1") do
      {:ok, _result} -> send_resp(conn, 200, "ok")
      {:error, _error} -> send_resp(conn, 503, "database unavailable")
    end
  end
end
