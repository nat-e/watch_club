defmodule WatchClubWeb.PlayerController do
  use WatchClubWeb, :controller

  alias WatchClub.Accounts.User
  alias WatchClub.Playbacks
  alias WatchClub.Playbacks.Playback.Hls

  plug :require_current_user

  def master_playlist(conn, %{"session_id" => session_id}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(with_active_playback(session_id, conn, &Hls.master_playlist/1))
  end

  def video_playlist(conn, %{"session_id" => session_id, "variant" => variant}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(with_active_playback(session_id, conn, &Hls.video_playlist(&1, variant)))
  end

  def audio_playlist(conn, %{"session_id" => session_id, "track_id" => track_id}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(with_active_playback(session_id, conn, &Hls.audio_playlist(&1, track_id)))
  end

  def subtitle_playlist(conn, %{"session_id" => session_id, "track_id" => track_id}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(
      with_active_playback(session_id, conn, &Hls.subtitle_playlist(&1, track_id))
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
      with_active_playback(session_id, conn, &Hls.video_segment(&1, variant, segment)),
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
      with_active_playback(session_id, conn, &Hls.audio_segment(&1, track_id, segment)),
      "video/mp2t"
    )
  end

  def subtitle_file(conn, %{
        "session_id" => session_id,
        "track_id" => track_id,
        "file" => file
      }) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_file_result(
      with_active_playback(session_id, conn, &Hls.subtitle_file(&1, track_id, file)),
      "text/vtt"
    )
  end

  defp with_active_playback(session_id, conn, fun) do
    case Playbacks.get_session_by_id(session_id, actor: conn.assigns.current_user) do
      {:ok, %{active_playback: %{} = playback}} -> fun.(playback)
      {:ok, _ended} -> {:error, :not_found}
      {:error, _reason} -> {:error, :not_found}
    end
  end

  defp require_current_user(%{assigns: %{current_user: %User{}}} = conn, _opts), do: conn

  defp require_current_user(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(401, "Unauthorized")
    |> halt()
  end

  defp send_text_result(conn, {:ok, body}) do
    conn
    |> put_resp_header("content-type", "application/vnd.apple.mpegurl")
    |> send_resp(200, body)
  end

  defp send_text_result(conn, {:error, :not_found}), do: send_not_found(conn)
  defp send_text_result(conn, {:error, _reason}), do: send_server_error(conn)

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

  defp send_file_result(conn, {:error, _reason}, _content_type), do: send_server_error(conn)

  defp send_not_found(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not found")
  end

  defp send_server_error(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(500, "Internal server error")
  end
end
