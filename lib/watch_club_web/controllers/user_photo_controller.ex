defmodule WatchClubWeb.UserPhotoController do
  @moduledoc """
  A User's photo. A new photo gets a new revision, so browsers keep each one for good.
  """
  use WatchClubWeb, :controller

  alias WatchClub.Accounts.UserPhoto

  def show(conn, %{"revision" => revision}) do
    path = UserPhoto.path(revision)

    if File.exists?(path) do
      conn
      |> put_resp_content_type("image/webp", nil)
      |> put_resp_header("cache-control", "private, max-age=31536000, immutable")
      |> send_file(200, path)
    else
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(404, "Not found")
    end
  end
end
