defmodule WatchClubWeb.PlayerController do
  use WatchClubWeb, :controller

  require Ash.Query
  require Logger

  alias WatchClub.Accounts.User
  alias WatchClub.Ffmpeg.Trickplay
  alias WatchClub.MediaCatalog.TextTrack
  alias WatchClub.Playbacks
  alias WatchClub.Playbacks.Playback.Hls

  @m3u8 "application/vnd.apple.mpegurl"

  @playback_fields [
    media: [
      video: [
        :default_video_track,
        audio_tracks: [:display_label],
        text_tracks:
          TextTrack
          |> Ash.Query.filter(hls_supported? == true)
          |> Ash.Query.load(:display_label)
      ]
    ]
  ]

  plug :require_current_user

  def master_playlist(conn, %{"playback_id" => playback_id}) do
    send_text_result(
      conn,
      with_active_playback(playback_id, conn, &Hls.master_playlist(&1.media.video)),
      @m3u8,
      "no-store"
    )
  end

  def video_playlist(conn, %{"playback_id" => playback_id, "variant" => variant}) do
    send_text_result(
      conn,
      with_active_playback(playback_id, conn, &Hls.video_playlist(&1.media.video, variant)),
      @m3u8,
      "no-store"
    )
  end

  def audio_playlist(conn, %{"playback_id" => playback_id, "track_id" => track_id}) do
    send_text_result(
      conn,
      with_active_playback(playback_id, conn, &Hls.audio_playlist(&1.media.video, track_id)),
      @m3u8,
      "no-store"
    )
  end

  def subtitle_playlist(conn, %{"playback_id" => playback_id, "track_id" => track_id}) do
    send_text_result(
      conn,
      with_active_playback(playback_id, conn, &Hls.subtitle_playlist(&1.media.video, track_id)),
      @m3u8,
      "no-store"
    )
  end

  def video_segment(conn, %{
        "playback_id" => playback_id,
        "variant" => variant,
        "segment" => segment
      }) do
    send_file_result(
      conn,
      with_active_playback(playback_id, conn, &Hls.video_segment(&1, variant, segment)),
      "video/mp2t",
      "public, max-age=3600"
    )
  end

  def audio_segment(conn, %{
        "playback_id" => playback_id,
        "track_id" => track_id,
        "segment" => segment
      }) do
    send_file_result(
      conn,
      with_active_playback(playback_id, conn, &Hls.audio_segment(&1, track_id, segment)),
      "video/mp2t",
      "public, max-age=3600"
    )
  end

  def subtitle_file(conn, %{
        "playback_id" => playback_id,
        "track_id" => track_id,
        "file" => file
      }) do
    send_file_result(
      conn,
      with_active_playback(playback_id, conn, &Hls.subtitle_file(&1, track_id, file)),
      "text/vtt",
      "public, max-age=3600"
    )
  end

  def thumbnails_file(conn, %{"playback_id" => playback_id, "file" => "thumbnails.vtt"}) do
    # Cue sprite refs must be origin-absolute and session-scoped, which only the
    # web layer knows — so the manifest is stamped with this base at serve time.
    base = Path.dirname(~p"/player/thumbnails/#{playback_id}/thumbnails.vtt")

    send_text_result(
      conn,
      with_active_playback(playback_id, conn, &Trickplay.manifest(&1.media.id, base)),
      "text/vtt",
      "public, max-age=3600"
    )
  end

  def thumbnails_file(conn, %{"playback_id" => playback_id, "file" => file}) do
    send_file_result(
      conn,
      with_active_playback(playback_id, conn, &Trickplay.sprite_path(&1.media.id, file)),
      "image/jpeg",
      "public, max-age=3600"
    )
  end

  defp with_active_playback(playback_id, conn, fun) do
    case Playbacks.get_playback_by_id(playback_id,
           load: @playback_fields,
           actor: conn.assigns.current_user
         ) do
      {:ok, playback} -> fun.(playback)
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

  # Cache-control is applied only on success so error responses are never
  # cached with the payload's freshness.
  defp send_text_result(conn, {:ok, body}, content_type, cache_control) do
    conn
    |> put_resp_header("cache-control", cache_control)
    |> put_resp_header("content-type", content_type)
    |> send_resp(200, body)
  end

  defp send_text_result(conn, {:error, :not_found}, _content_type, _cache_control),
    do: send_not_found(conn)

  defp send_text_result(conn, {:error, reason}, _content_type, _cache_control),
    do: send_server_error(conn, reason)

  defp send_file_result(conn, {:ok, path}, content_type, cache_control) do
    conn
    |> put_resp_header("cache-control", cache_control)
    |> put_resp_header("content-type", content_type)
    |> send_file(200, path)
  end

  defp send_file_result(conn, {:error, :not_found}, _content_type, _cache_control),
    do: send_not_found(conn)

  defp send_file_result(conn, {:error, :invalid_segment}, _content_type, _cache_control) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(400, "Bad request")
  end

  defp send_file_result(conn, {:error, reason}, _content_type, _cache_control),
    do: send_server_error(conn, reason)

  defp send_not_found(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not found")
  end

  defp send_server_error(conn, reason) do
    Logger.error("Player — Request failed", event: :player_request_failed, error: reason)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(500, "Internal server error")
  end
end
