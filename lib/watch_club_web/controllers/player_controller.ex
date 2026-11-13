defmodule WatchClubWeb.PlayerController do
  use WatchClubWeb, :controller

  require Ash.Query
  require Logger

  alias WatchClub.Ffmpeg.Trickplay
  alias WatchClub.MediaCatalog.TextTrack
  alias WatchClub.Playbacks
  alias WatchClub.Playbacks.Playback
  alias WatchClub.Playbacks.Playback.Hls
  alias WatchClub.SystemActor
  alias WatchClubWeb.Helpers.PlaybackPaths

  @m3u8 "application/vnd.apple.mpegurl"

  @playback_fields [
    media: [
      video: [
        :default_video_track,
        audio_tracks: [:display_label, :language_code],
        text_tracks: Ash.Query.filter(TextTrack, hls_supported? == true)
      ]
    ]
  ]

  def master_playlist(conn, params) do
    query = PlaybackPaths.query(params["token"])

    send_text_result(
      conn,
      with_current_playback(params, &Hls.master_playlist(&1, query)),
      @m3u8,
      "no-store"
    )
  end

  def video_playlist(conn, %{"variant" => variant} = params) do
    query = PlaybackPaths.query(params["token"])

    send_text_result(
      conn,
      with_current_playback(params, &Hls.video_playlist(&1.media.video, variant, query)),
      @m3u8,
      "no-store"
    )
  end

  def audio_playlist(conn, %{"track_id" => track_id} = params) do
    query = PlaybackPaths.query(params["token"])

    send_text_result(
      conn,
      with_current_playback(params, &Hls.audio_playlist(&1.media.video, track_id, query)),
      @m3u8,
      "no-store"
    )
  end

  def video_segment(conn, %{"variant" => variant, "segment" => segment} = params) do
    send_file_result(
      conn,
      with_current_playback(params, &Hls.video_segment(&1, variant, segment)),
      "video/mp2t",
      "public, max-age=3600"
    )
  end

  def audio_segment(conn, %{"track_id" => track_id, "segment" => segment} = params) do
    send_file_result(
      conn,
      with_current_playback(params, &Hls.audio_segment(&1, track_id, segment)),
      "video/mp2t",
      "public, max-age=3600"
    )
  end

  def subtitle_file(conn, %{"track_id" => track_id, "file" => file} = params) do
    send_file_result(
      conn,
      with_current_playback(params, &Hls.subtitle_file(&1, track_id, file)),
      "text/vtt",
      "public, max-age=3600"
    )
  end

  def thumbnails_file(
        conn,
        %{"playback_id" => playback_id, "file" => "thumbnails.vtt"} = params
      ) do
    # Cue sprite refs must be origin-absolute and Playback-scoped, which only the
    # web layer knows — so the manifest is stamped with this base at serve time.
    base = Path.dirname(~p"/player/thumbnails/#{playback_id}/thumbnails.vtt")
    query = PlaybackPaths.query(params["token"])

    send_text_result(
      conn,
      with_current_playback(params, &Trickplay.manifest(&1.media.id, base, query)),
      "text/vtt",
      "public, max-age=3600"
    )
  end

  def thumbnails_file(conn, %{"file" => file} = params) do
    send_file_result(
      conn,
      with_current_playback(params, &Trickplay.sprite_path(&1.media.id, file)),
      "image/jpeg",
      "public, max-age=3600"
    )
  end

  # The token in the query opens the files of the Playback in the path, while it's current
  defp with_current_playback(%{"playback_id" => playback_id} = params, fun) do
    with true <- PlaybackPaths.opens?(params["token"], playback_id),
         {:ok, %Playback{ended_at: nil} = playback} <-
           Playbacks.get_playback_by_id(playback_id,
             load: @playback_fields,
             actor: SystemActor.actor()
           ) do
      fun.(playback)
    else
      _invalid_token_or_ended_playback -> {:error, :not_found}
    end
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
