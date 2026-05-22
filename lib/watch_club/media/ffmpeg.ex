defmodule WatchClub.Media.Ffmpeg do
  @moduledoc """
  ffmpeg CLI wrapper.

  Currently exposes a small set of HLS-shaped transcodes (mpegts segments
  and webvtt subtitle files); the entry points encode the ffmpeg flag
  choices so callers don't have to know them. Add new entry points here
  when new ffmpeg use cases appear.

  Each transcode writes to a `.tmp` sibling first, then atomically renames
  into the requested output path on success. Concurrent requests for the
  same path are therefore safe: at worst they duplicate CPU work, but the
  final file is never seen partially written.
  """

  require Logger

  def transcode_video_segment(job) do
    run_ffmpeg(Map.put(job, :type, :video))
  end

  def transcode_audio_segment(job) do
    run_ffmpeg(Map.put(job, :type, :audio))
  end

  def transcode_subtitle_file(job) do
    run_ffmpeg(Map.put(job, :type, :subtitle))
  end

  defp run_ffmpeg(%{type: :video} = job) do
    File.mkdir_p!(Path.dirname(job.output_path))
    tmp_path = tmp_path(job.output_path)

    filters = "scale=#{job.width}:#{job.height},setsar=1,format=yuv420p"

    args = [
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      "-ss",
      seconds(job.start_time),
      "-i",
      job.source_path,
      "-t",
      seconds(job.duration),
      "-map",
      "0:v:0",
      "-an",
      "-sn",
      "-vf",
      filters,
      "-c:v",
      "libx264",
      "-preset",
      "ultrafast",
      "-profile:v",
      "main",
      "-pix_fmt",
      "yuv420p",
      "-b:v",
      bitrate(job.video_bitrate),
      "-maxrate",
      bitrate(round(job.video_bitrate * 1.2)),
      "-bufsize",
      bitrate(job.video_bitrate * 2),
      "-force_key_frames",
      "expr:gte(t,n_forced*#{seconds(job.segment_duration)})",
      "-avoid_negative_ts",
      "make_zero",
      "-muxpreload",
      "0",
      "-muxdelay",
      "0",
      "-f",
      "mpegts",
      tmp_path
    ]

    run_command(args, tmp_path, job.output_path)
  end

  defp run_ffmpeg(%{type: :audio} = job) do
    File.mkdir_p!(Path.dirname(job.output_path))
    tmp_path = tmp_path(job.output_path)

    args = [
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      "-ss",
      seconds(job.start_time),
      "-i",
      job.source_path,
      "-t",
      seconds(job.duration),
      "-map",
      "0:#{job.stream_index}",
      "-vn",
      "-sn",
      "-c:a",
      "aac",
      "-ac",
      "2",
      "-b:a",
      "160k",
      "-ar",
      "48000",
      "-avoid_negative_ts",
      "make_zero",
      "-muxpreload",
      "0",
      "-muxdelay",
      "0",
      "-f",
      "mpegts",
      tmp_path
    ]

    run_command(args, tmp_path, job.output_path)
  end

  defp run_ffmpeg(%{type: :subtitle} = job) do
    File.mkdir_p!(Path.dirname(job.output_path))
    tmp_path = tmp_path(job.output_path)

    args = [
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      "-i",
      job.source_path,
      "-map",
      "0:#{job.stream_index}",
      "-c:s",
      "webvtt",
      tmp_path
    ]

    run_command(args, tmp_path, job.output_path)
  end

  defp run_command(args, tmp_path, output_path) do
    Logger.debug("Running HLS ffmpeg job: ffmpeg #{Enum.join(args, " ")}")

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_output, 0} ->
        File.rename!(tmp_path, output_path)
        {:ok, output_path}

      {output, status} ->
        File.rm(tmp_path)
        {:error, "ffmpeg exited with #{status}: #{String.trim(output)}"}
    end
  rescue
    exception ->
      File.rm(tmp_path)
      {:error, Exception.message(exception)}
  end

  defp tmp_path(output_path) do
    suffix = :erlang.unique_integer([:positive])
    "#{output_path}.#{suffix}.tmp"
  end

  defp seconds(value) when is_integer(value), do: Integer.to_string(value)
  defp seconds(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 3)

  defp bitrate(value) when is_integer(value), do: "#{value}"
  defp bitrate(value) when is_float(value), do: value |> round() |> bitrate()
end
