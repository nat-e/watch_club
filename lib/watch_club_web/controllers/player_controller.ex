defmodule WatchClubWeb.PlayerController do
  use WatchClubWeb, :controller

  alias WatchClub.Accounts.User
  alias WatchClub.Playback

  plug :require_current_user

  def master_playlist(conn, %{"stream_id" => stream_id}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(
      Playback.get_master_playlist(stream_id, actor: conn.assigns.current_user),
      "application/vnd.apple.mpegurl"
    )
  end

  def video_playlist(conn, %{"stream_id" => stream_id, "variant" => variant}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(
      Playback.get_video_playlist(stream_id, variant, actor: conn.assigns.current_user),
      "application/vnd.apple.mpegurl"
    )
  end

  def audio_playlist(conn, %{"stream_id" => stream_id, "track_id" => track_id}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(
      Playback.get_audio_playlist(stream_id, track_id, actor: conn.assigns.current_user),
      "application/vnd.apple.mpegurl"
    )
  end

  def subtitle_playlist(conn, %{"stream_id" => stream_id, "track_id" => track_id}) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_text_result(
      Playback.get_subtitle_playlist(stream_id, track_id, actor: conn.assigns.current_user),
      "application/vnd.apple.mpegurl"
    )
  end

  def video_segment(conn, %{
        "stream_id" => stream_id,
        "variant" => variant,
        "segment" => segment
      }) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_file_result(
      Playback.get_video_segment(stream_id, variant, segment, actor: conn.assigns.current_user),
      "video/mp2t"
    )
  end

  def audio_segment(conn, %{
        "stream_id" => stream_id,
        "track_id" => track_id,
        "segment" => segment
      }) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_file_result(
      Playback.get_audio_segment(stream_id, track_id, segment, actor: conn.assigns.current_user),
      "video/mp2t"
    )
  end

  def subtitle_file(conn, %{"stream_id" => stream_id, "track_id" => track_id, "file" => file}) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_file_result(
      Playback.get_subtitle_file(stream_id, track_id, file, actor: conn.assigns.current_user),
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
