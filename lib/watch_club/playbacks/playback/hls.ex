defmodule WatchClub.Playbacks.Playback.Hls do
  @moduledoc """
  Helpers functions for building HLS playlists for videos and transcoding
  HLS segments.

  Segments are cut on the keyframes of the Video's Default Video Track: each starts on the
  first keyframe at or after a multiple of 6 seconds, so that every quality and audio track cuts
  at the same times. A quality copies the file's video or encodes it, see `QualityLadder`.

  MPEG-TS and MPEG-PS files (`.ts`, `.m2ts`, `.mpg`) aren't supported: their segments can miss
  frames. ffmpeg can't seek them to a keyframe, as they have no index, and counts their times from
  the start of the stream it reads rather than from the start of the file.

  Segments are cached on disk at the Playback level. `SegmentQueue` makes them, and makes the
  `@segments_ahead` segments after each one a Screen asks for, of the same quality or audio track.
  """

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  alias WatchClub.Ffmpeg
  alias WatchClub.MediaCatalog.{AudioTrack, TextTrack, Video}
  alias WatchClub.Playbacks.Playback
  alias WatchClub.Playbacks.Playback.{Playlist, QualityLadder, SegmentCache, SegmentQueue}

  @segment_duration 6.0
  # About 30 s and more than 24 s, most of the Player's buffer
  @segments_ahead 5

  @doc "`query`, such as `?token=…`, follows every URI of the playlists, which need it."
  def master_playlist(%Playback{media: %{video: %Video{} = video}} = playback, query) do
    metadata = %{
      video: video.default_video_track,
      audio_tracks: video.audio_tracks,
      default_audio_track_id: playback.audio_track_id,
      query: query
    }

    qualities = QualityLadder.build(video, segments(video))
    {:ok, IO.iodata_to_binary(Playlist.master(metadata, qualities))}
  end

  def video_playlist(%Video{} = video, variant_id, query) do
    with {:ok, _quality} <- find_quality(video, variant_id) do
      {:ok, render_media_playlist(video, query)}
    end
  end

  def audio_playlist(%Video{} = video, track_id, query) do
    with {:ok, _track} <- find_audio_track(video, track_id) do
      {:ok, render_media_playlist(video, query)}
    end
  end

  def video_segment(%Playback{} = playback, variant_id, segment_name) do
    with {:ok, quality} <- find_quality(playback.media.video, variant_id),
         {:ok, index} <- parse_segment_name(segment_name),
         {:ok, [job | next_jobs]} <-
           segment_jobs(
             playback.media.video,
             index,
             &video_segment_job(playback, quality, &1, &2)
           ) do
      SegmentQueue.fetch({playback.id, :video}, job, next_jobs)
    end
  end

  def audio_segment(%Playback{} = playback, track_id, segment_name) do
    with {:ok, track} <- find_audio_track(playback.media.video, track_id),
         {:ok, index} <- parse_segment_name(segment_name),
         {:ok, [job | next_jobs]} <-
           segment_jobs(playback.media.video, index, &audio_segment_job(playback, track, &1, &2)) do
      SegmentQueue.fetch({playback.id, :audio}, job, next_jobs)
    end
  end

  def subtitle_file(%Playback{} = playback, track_id, file_name) do
    with {:ok, track} <- find_subtitle_track(playback.media.video, track_id),
         :ok <- ensure_expected_subtitle_file(track, file_name) do
      ensure_subtitle_file(playback, track)
    end
  end

  defp render_media_playlist(%Video{} = video, query) do
    durations = Enum.map(segments(video), & &1.duration)
    IO.iodata_to_binary(Playlist.segments(durations, query))
  end

  # The Video's segments, in order: the first starts with the file, the others on a keyframe.
  # Each holds the bytes of the Default Video Track from its keyframes.
  defp segments(%Video{
         keyframe_seconds: keyframes,
         keyframe_interval_bytes: interval_bytes,
         duration_seconds: duration
       }) do
    segments =
      keyframes
      |> Enum.zip(interval_bytes)
      |> Enum.reduce([%{start_time: 0.0, video_bytes: 0}], fn {keyframe, bytes},
                                                              [segment | previous] = segments ->
        next_mark = (Float.floor(segment.start_time / @segment_duration) + 1) * @segment_duration

        if keyframe >= next_mark and keyframe < duration do
          [%{start_time: keyframe, video_bytes: bytes} | segments]
        else
          [%{segment | video_bytes: segment.video_bytes + bytes} | previous]
        end
      end)
      |> Enum.reverse()

    end_times = Enum.map(tl(segments), & &1.start_time) ++ [duration]

    Enum.zip_with(segments, end_times, fn segment, end_time ->
      Map.merge(segment, %{
        end_time: end_time,
        duration: Float.round(end_time - segment.start_time, 6)
      })
    end)
  end

  # The jobs of the segment at `index` and of the `@segments_ahead` next ones
  defp segment_jobs(%Video{} = video, index, segment_job) do
    case video |> segments() |> Enum.with_index() |> Enum.slice(index, @segments_ahead + 1) do
      [] ->
        {:error, :not_found}

      segments ->
        {:ok, Enum.map(segments, fn {segment, index} -> segment_job.(segment, index) end)}
    end
  end

  defp video_segment_job(%Playback{} = playback, quality, segment, index) do
    output_path = video_segment_path(playback, quality, index)

    ffmpeg_job =
      segment
      |> Map.take([:start_time, :end_time])
      |> Map.merge(%{
        source_path: playback.media.path,
        output_path: output_path,
        stream_index: playback.media.video.default_video_track.stream_index
      })

    make = fn ->
      if quality.copy? do
        attributes = %{"watch_club.hls.segment_index": index}

        trace_transcode("copy video segment", attributes, fn ->
          Ffmpeg.copy_video_segment(ffmpeg_job)
        end)
      else
        attributes = %{
          "watch_club.hls.quality": quality.id,
          "watch_club.hls.segment_index": index
        }

        trace_transcode("transcode video segment", attributes, fn ->
          ffmpeg_job
          |> Map.merge(Map.take(quality, [:width, :height, :video_bitrate, :level]))
          |> Ffmpeg.transcode_video_segment()
        end)
      end
    end

    %{output_path: output_path, make: make}
  end

  defp audio_segment_job(%Playback{} = playback, %AudioTrack{} = track, segment, index) do
    output_path = audio_segment_path(playback, track, index)

    ffmpeg_job = %{
      source_path: playback.media.path,
      output_path: output_path,
      start_time: segment.start_time,
      end_time: segment.end_time,
      stream_index: track.stream_index
    }

    attributes = %{
      "watch_club.audio_track.stream_index": track.stream_index,
      "watch_club.hls.segment_index": index
    }

    make = fn ->
      trace_transcode("transcode audio segment", attributes, fn ->
        Ffmpeg.transcode_audio_segment(ffmpeg_job)
      end)
    end

    %{output_path: output_path, make: make}
  end

  defp ensure_subtitle_file(%Playback{} = playback, %TextTrack{} = track) do
    output_path = subtitle_file_path(playback, track)

    if SegmentCache.cached?(output_path) do
      {:ok, output_path}
    else
      source = if track.sidecar_path, do: :sidecar, else: :embedded

      attributes = %{
        "watch_club.text_track.source": source,
        "watch_club.text_track.codec": track.codec
      }

      trace_transcode("transcode Text Track", attributes, fn ->
        # A sidecar file holds a single stream, at index 0
        result =
          Ffmpeg.transcode_subtitle_file(%{
            source_path: track.sidecar_path || playback.media.path,
            output_path: output_path,
            stream_index: track.stream_index || 0,
            character_encoding: sidecar_character_encoding(track)
          })

        with {:ok, _output_path} <- result do
          Logger.info("Converted #{source} #{track.codec} Text Track to WebVTT",
            event: :text_track_converted
          )

          result
        end
      end)
    end
  end

  # Matroska and MP4 store text subtitles as UTF-8. A sidecar file that isn't
  # UTF-8 is most likely an old Western European file in Windows-1252.
  defp sidecar_character_encoding(%TextTrack{sidecar_path: nil}), do: nil

  defp sidecar_character_encoding(%TextTrack{sidecar_path: path}) do
    if String.valid?(File.read!(path)) do
      nil
    else
      Logger.warning("Sidecar Text Track isn't UTF-8, reading it as Windows-1252: #{path}",
        event: :text_track_read_as_windows_1252
      )

      "CP1252"
    end
  end

  # Runs an FFmpeg transcode in its own span, marked as an error when it fails
  defp trace_transcode(span_name, attributes, transcode) do
    Tracer.with_span span_name, %{attributes: attributes} do
      with {:error, reason} = error <- transcode.() do
        Tracer.set_status(:error, reason)
        error
      end
    end
  end

  defp ensure_expected_subtitle_file(%TextTrack{} = track, file_name) do
    if file_name == "#{track.id}.vtt", do: :ok, else: {:error, :not_found}
  end

  defp find_quality(%Video{} = video, id) do
    case Enum.find(QualityLadder.build(video, segments(video)), &(&1.id == id)) do
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
end
