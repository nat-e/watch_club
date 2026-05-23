defmodule WatchClub.Playbacks.Playback.Hls do
  @moduledoc """
  Pure rendering layer for a Playback's HLS output.

  Every function takes a `Playback` loaded through `:for_hls_playback`, which
  guarantees the Playback is active and that the media graph (video, audio
  tracks, HLS-supported text tracks) is loaded. This module owns concerns
  that only make sense in the HLS context: the quality ladder, segment-cache
  paths, HLS wire-format conventions, and ffmpeg invocation.
  """

  alias WatchClub.Media.Ffmpeg
  alias WatchClub.Playbacks.Playback.{Playlist, QualityLadder, SegmentCache}

  @segment_duration 6.0

  @doc "Segment duration in seconds used by the player and the playlists."
  def segment_duration, do: @segment_duration

  @doc "Number of segments needed to cover the Playback's source duration."
  def segment_count(playback) do
    playback
    |> duration()
    |> Kernel./(@segment_duration)
    |> Float.ceil()
    |> trunc()
  end

  def master_playlist(playback) do
    video = playback.media.video

    metadata = %{
      video: hd(video.video_tracks),
      audio_tracks: video.audio_tracks,
      subtitle_tracks: video.text_tracks
    }

    {:ok, IO.iodata_to_binary(Playlist.master(metadata, qualities(playback)))}
  end

  def video_playlist(playback, variant_id) do
    with {:ok, _quality} <- find_quality(playback, variant_id) do
      {:ok, render_media_playlist(playback)}
    end
  end

  def audio_playlist(playback, track_id) do
    with {:ok, _track} <- find_audio_track(playback, track_id) do
      {:ok, render_media_playlist(playback)}
    end
  end

  def subtitle_playlist(playback, track_id) do
    with {:ok, track} <- find_subtitle_track(playback, track_id) do
      {:ok, IO.iodata_to_binary(Playlist.subtitle(track, duration(playback)))}
    end
  end

  def video_segment(playback, variant_id, segment_name) do
    with {:ok, quality} <- find_quality(playback, variant_id),
         {:ok, index} <- parse_segment_name(segment_name),
         :ok <- validate_segment_index(playback, index) do
      ensure_video_segment(playback, quality, index)
    end
  end

  def audio_segment(playback, track_id, segment_name) do
    with {:ok, track} <- find_audio_track(playback, track_id),
         {:ok, index} <- parse_segment_name(segment_name),
         :ok <- validate_segment_index(playback, index) do
      ensure_audio_segment(playback, track, index)
    end
  end

  def subtitle_file(playback, track_id, file_name) do
    with {:ok, track} <- find_subtitle_track(playback, track_id),
         :ok <- ensure_expected_subtitle_file(track, file_name) do
      ensure_subtitle_file(playback, track)
    end
  end

  defp render_media_playlist(playback) do
    IO.iodata_to_binary(
      Playlist.segments(duration(playback), segment_count(playback), @segment_duration)
    )
  end

  defp ensure_video_segment(playback, quality, index) do
    output_path = video_segment_path(playback, quality, index)

    if cached?(output_path) do
      {:ok, output_path}
    else
      Ffmpeg.transcode_video_segment(%{
        source_path: playback.media.path,
        output_path: output_path,
        start_time: index * @segment_duration,
        duration: segment_duration_at(playback, index),
        segment_duration: @segment_duration,
        width: quality.width,
        height: quality.height,
        video_bitrate: quality.video_bitrate
      })
    end
  end

  defp ensure_audio_segment(playback, track, index) do
    output_path = audio_segment_path(playback, track, index)

    if cached?(output_path) do
      {:ok, output_path}
    else
      Ffmpeg.transcode_audio_segment(%{
        source_path: playback.media.path,
        output_path: output_path,
        start_time: index * @segment_duration,
        duration: segment_duration_at(playback, index),
        stream_index: track.stream_index
      })
    end
  end

  defp ensure_subtitle_file(playback, track) do
    output_path = subtitle_file_path(playback, track)

    if cached?(output_path) do
      {:ok, output_path}
    else
      Ffmpeg.transcode_subtitle_file(%{
        source_path: playback.media.path,
        output_path: output_path,
        stream_index: track.stream_index
      })
    end
  end

  defp ensure_expected_subtitle_file(track, file_name) do
    if file_name == "#{track.id}.vtt", do: :ok, else: {:error, :not_found}
  end

  defp duration(playback), do: playback.media.video.duration_seconds

  defp qualities(playback) do
    track = hd(playback.media.video.video_tracks)
    QualityLadder.build(track.width, track.height, track.bit_rate)
  end

  defp find_quality(playback, id) do
    case Enum.find(qualities(playback), &(&1.id == id)) do
      nil -> {:error, :not_found}
      quality -> {:ok, quality}
    end
  end

  defp find_audio_track(playback, id) do
    case Enum.find(playback.media.video.audio_tracks, &(&1.id == id)) do
      nil -> {:error, :not_found}
      track -> {:ok, track}
    end
  end

  defp find_subtitle_track(playback, id) do
    case Enum.find(playback.media.video.text_tracks, &(&1.id == id)) do
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

  defp validate_segment_index(playback, index) do
    if index >= 0 and index < segment_count(playback) do
      :ok
    else
      {:error, :not_found}
    end
  end

  defp segment_duration_at(playback, index) do
    remaining = duration(playback) - index * @segment_duration
    min(@segment_duration, max(remaining, 0.1))
  end

  defp video_segment_path(playback, quality, index) do
    Path.join([
      SegmentCache.playback_dir(playback.id),
      "video",
      quality.id,
      "seg_#{Playlist.pad_segment(index)}.ts"
    ])
  end

  defp audio_segment_path(playback, track, index) do
    Path.join([
      SegmentCache.playback_dir(playback.id),
      "audio",
      track.id,
      "seg_#{Playlist.pad_segment(index)}.ts"
    ])
  end

  defp subtitle_file_path(playback, track) do
    Path.join([SegmentCache.playback_dir(playback.id), "subtitles", track.id, "#{track.id}.vtt"])
  end

  defp cached?(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > 0 -> true
      _other -> false
    end
  end
end
