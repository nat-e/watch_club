defmodule WatchClubWeb.PlayerController do
  use WatchClubWeb, :controller

  alias WatchClub.Accounts.User
  alias WatchClub.Playback.PlaybackSessionManager

  plug :require_current_user

  def master_playlist(conn, %{"session_id" => session_id}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(
      PlaybackSessionManager.master_playlist(conn.assigns.current_user.id, session_id),
      "application/vnd.apple.mpegurl"
    )
  end

  def video_playlist(conn, %{"session_id" => session_id, "variant" => variant}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(
      PlaybackSessionManager.video_playlist(conn.assigns.current_user.id, session_id, variant),
      "application/vnd.apple.mpegurl"
    )
  end

  def audio_playlist(conn, %{"session_id" => session_id, "track_id" => track_id}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(
      PlaybackSessionManager.audio_playlist(conn.assigns.current_user.id, session_id, track_id),
      "application/vnd.apple.mpegurl"
    )
  end

  def subtitle_playlist(conn, %{"session_id" => session_id, "track_id" => track_id}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(
      PlaybackSessionManager.subtitle_playlist(conn.assigns.current_user.id, session_id, track_id),
      "application/vnd.apple.mpegurl"
    )
  end

  def video_segment(conn, %{
        "session_id" => session_id,
        "variant" => variant,
        "segment" => segment
      }) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_file_result(
      PlaybackSessionManager.video_segment(
        conn.assigns.current_user.id,
        session_id,
        variant,
        segment
      ),
      "video/mp2t"
    )
  end

  def audio_segment(conn, %{
        "session_id" => session_id,
        "track_id" => track_id,
        "segment" => segment
      }) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_file_result(
      PlaybackSessionManager.audio_segment(
        conn.assigns.current_user.id,
        session_id,
        track_id,
        segment
      ),
      "video/mp2t"
    )
  end

  def subtitle_file(conn, %{"session_id" => session_id, "track_id" => track_id, "file" => file}) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_file_result(
      PlaybackSessionManager.subtitle_file(
        conn.assigns.current_user.id,
        session_id,
        track_id,
        file
      ),
      "text/vtt"
    )
  end

  defp require_current_user(%{assigns: %{current_user: %User{}}} = conn, _opts), do: conn

  defp require_current_user(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(401, "Unauthorized")
    |> halt()
  end

  defp send_text_result(conn, {:ok, body}, content_type) do
    conn
    |> put_resp_header("content-type", content_type)
    |> send_resp(200, body)
  end

  defp send_text_result(conn, {:error, :not_found}, _content_type), do: send_not_found(conn)

  defp send_text_result(conn, {:error, reason}, _content_type) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(500, inspect(reason))
  end

  defp send_file_result(conn, {:ok, path}, content_type) do
    conn
    |> put_resp_header("content-type", content_type)
    |> send_file(200, path)
  end

  defp send_file_result(conn, {:error, :not_found}, _content_type), do: send_not_found(conn)

  defp send_file_result(conn, {:error, :invalid_segment}, _content_type) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(400, "Bad request")
  end

  defp send_file_result(conn, {:error, reason}, _content_type) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(500, inspect(reason))
  end

  defp send_not_found(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not found")
  end
end
