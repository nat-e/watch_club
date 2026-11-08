defmodule WatchClub.Playbacks.Playback.Hls do
  @moduledoc """
  Helpers functions for building HLS playlists for videos and transcoding
  HLS segments.

  Transcoded segments are cached on disk at the Playback level.
  """

  alias WatchClub.Ffmpeg
  alias WatchClub.MediaCatalog.{AudioTrack, TextTrack, Video}
  alias WatchClub.Playbacks.Playback
  alias WatchClub.Playbacks.Playback.{Playlist, QualityLadder, SegmentCache}

  @segment_duration 6.0

  @doc "Segment duration in seconds used by the player and the playlists."
  def segment_duration, do: @segment_duration

  @doc "Number of segments needed to cover the Playback's source duration."
  def segment_count(video) do
    (video.duration_seconds / @segment_duration)
    |> Float.ceil()
    |> trunc()
  end

  def master_playlist(%Video{} = video) do
    metadata = %{
      video: video.default_video_track,
      audio_tracks: video.audio_tracks,
      subtitle_tracks: video.text_tracks
    }

    {:ok, IO.iodata_to_binary(Playlist.master(metadata, qualities(video)))}
  end

  def video_playlist(%Video{} = video, variant_id) do
    with {:ok, _quality} <- find_quality(video, variant_id) do
      {:ok, render_media_playlist(video)}
    end
  end

  def audio_playlist(%Video{} = video, track_id) do
    with {:ok, _track} <- find_audio_track(video, track_id) do
      {:ok, render_media_playlist(video)}
    end
  end

  def subtitle_playlist(%Video{} = video, track_id) do
    with {:ok, track} <- find_subtitle_track(video, track_id) do
      {:ok, IO.iodata_to_binary(Playlist.subtitle(track, video.duration_seconds))}
    end
  end

  def video_segment(%Playback{} = playback, variant_id, segment_name) do
    with {:ok, quality} <- find_quality(playback.media.video, variant_id),
         {:ok, index} <- parse_segment_name(segment_name),
         :ok <- validate_segment_index(playback.media.video, index) do
      ensure_video_segment(playback, quality, index)
    end
  end

  def audio_segment(%Playback{} = playback, track_id, segment_name) do
    with {:ok, track} <- find_audio_track(playback.media.video, track_id),
         {:ok, index} <- parse_segment_name(segment_name),
         :ok <- validate_segment_index(playback.media.video, index) do
      ensure_audio_segment(playback, track, index)
    end
  end

  def subtitle_file(%Playback{} = playback, track_id, file_name) do
    with {:ok, track} <- find_subtitle_track(playback.media.video, track_id),
         :ok <- ensure_expected_subtitle_file(track, file_name) do
      ensure_subtitle_file(playback, track)
    end
  end

  defp render_media_playlist(%Video{} = video) do
    IO.iodata_to_binary(
      Playlist.segments(video.duration_seconds, segment_count(video), @segment_duration)
    )
  end

  defp ensure_video_segment(%Playback{} = playback, quality, index) do
    output_path = video_segment_path(playback, quality, index)

    if cached?(output_path) do
      {:ok, output_path}
    else
      Ffmpeg.transcode_video_segment(%{
        source_path: playback.media.path,
        output_path: output_path,
        start_time: index * @segment_duration,
        duration: segment_duration_at(playback.media.video, index),
        segment_duration: @segment_duration,
        width: quality.width,
        height: quality.height,
        video_bitrate: quality.video_bitrate
      })
    end
  end

  defp ensure_audio_segment(%Playback{} = playback, %AudioTrack{} = track, index) do
    output_path = audio_segment_path(playback, track, index)

    if cached?(output_path) do
      {:ok, output_path}
    else
      Ffmpeg.transcode_audio_segment(%{
        source_path: playback.media.path,
        output_path: output_path,
        start_time: index * @segment_duration,
        duration: segment_duration_at(playback.media.video, index),
        stream_index: track.stream_index
      })
    end
  end

  defp ensure_subtitle_file(%Playback{} = playback, %TextTrack{} = track) do
    output_path = subtitle_file_path(playback, track)

    if cached?(output_path) do
      {:ok, output_path}
    else
      # An external subtitle file holds a single stream, at index 0
      Ffmpeg.transcode_subtitle_file(%{
        source_path: track.sidecar_path || playback.media.path,
        output_path: output_path,
        stream_index: track.stream_index || 0
      })
    end
  end

  defp ensure_expected_subtitle_file(%TextTrack{} = track, file_name) do
    if file_name == "#{track.id}.vtt", do: :ok, else: {:error, :not_found}
  end

  defp qualities(%Video{} = video) do
    track = video.default_video_track
    QualityLadder.build(track.width, track.height, track.bit_rate)
  end

  defp find_quality(%Video{} = video, id) do
    case Enum.find(qualities(video), &(&1.id == id)) do
      nil -> {:error, :not_found}
      quality -> {:ok, quality}
    end
  end

  defp find_audio_track(%Video{} = video, id) do
    case Enum.find(video.audio_tracks, &(&1.id == id)) do
      nil -> {:error, :not_found}
      track -> {:ok, track}
    end
  end

  defp find_subtitle_track(%Video{} = video, id) do
    case Enum.find(video.text_tracks, &(&1.id == id)) do
      nil -> {:error, :not_found}
      track -> {:ok, track}
    end
  end

  defp parse_segment_name(segment_name) do
    case Regex.run(~r/^seg_(\d+)\.ts$/, segment_name) do
      [_segment_name, index] -> {:ok, String.to_integer(index)}
      _no_match -> {:error, :invalid_segment}
    end
  end

  defp validate_segment_index(%Video{} = video, index) do
    if index >= 0 and index < segment_count(video) do
      :ok
    else
      {:error, :not_found}
    end
  end

  defp segment_duration_at(%Video{} = video, index) do
    remaining = video.duration_seconds - index * @segment_duration
    min(@segment_duration, max(remaining, 0.1))
  end

  defp video_segment_path(%Playback{} = playback, quality, index) do
    Path.join([
      SegmentCache.playback_dir(playback.id),
      "video",
      quality.id,
      "seg_#{Playlist.pad_segment(index)}.ts"
    ])
  end

  defp audio_segment_path(%Playback{} = playback, %AudioTrack{} = track, index) do
    Path.join([
      SegmentCache.playback_dir(playback.id),
      "audio",
      track.id,
      "seg_#{Playlist.pad_segment(index)}.ts"
    ])
  end

  defp subtitle_file_path(%Playback{} = playback, track) do
    Path.join([SegmentCache.playback_dir(playback.id), "subtitles", track.id, "#{track.id}.vtt"])
  end

  defp cached?(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > 0 -> true
      _other -> false
    end
  end
end
