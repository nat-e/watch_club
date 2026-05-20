defmodule WatchClubWeb.PlayerController do
  use WatchClubWeb, :controller

  alias WatchClub.Playback.HlsSession

  def master_playlist(conn, %{"session_id" => session_id}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(HlsSession.master_playlist(session_id), "application/vnd.apple.mpegurl")
  end

  def video_playlist(conn, %{"session_id" => session_id, "variant" => variant}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(
      HlsSession.video_playlist(session_id, variant),
      "application/vnd.apple.mpegurl"
    )
  end

  def audio_playlist(conn, %{"session_id" => session_id, "track_id" => track_id}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(
      HlsSession.audio_playlist(session_id, track_id),
      "application/vnd.apple.mpegurl"
    )
  end

  def subtitle_playlist(conn, %{"session_id" => session_id, "track_id" => track_id}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(
      HlsSession.subtitle_playlist(session_id, track_id),
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
    |> send_file_result(HlsSession.video_segment(session_id, variant, segment), "video/mp2t")
  end

  def audio_segment(conn, %{
        "session_id" => session_id,
        "track_id" => track_id,
        "segment" => segment
      }) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_file_result(HlsSession.audio_segment(session_id, track_id, segment), "video/mp2t")
  end

  def subtitle_file(conn, %{"session_id" => session_id, "track_id" => track_id, "file" => file}) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_file_result(HlsSession.subtitle_file(session_id, track_id, file), "text/vtt")
  end

  defp send_text_result(conn, {:ok, body}, content_type) do
    conn
    |> put_resp_header("content-type", content_type)
    |> send_resp(200, body)
  end

  defp send_text_result(conn, {:error, :not_found}, _content_type) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not found")
  end

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

  defp send_file_result(conn, {:error, :not_found}, _content_type) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not found")
  end

  defp send_file_result(conn, {:error, reason}, _content_type) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(500, inspect(reason))
  end
end
