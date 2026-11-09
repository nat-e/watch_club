defmodule WatchClub.Ffmpeg do
  @moduledoc """
  ffmpeg CLI wrapper.

  Currently exposes a small set of HLS-shaped transcodes (mpegts segments
  and webvtt subtitle files), and the file inspections of
  `WatchClub.Ffmpeg.Probe`; the entry points encode the ffmpeg flag
  choices so callers don't have to know them. Add new entry points here
  when new ffmpeg use cases appear.

  Each transcode writes to a `.tmp` sibling first, then atomically renames
  into the requested output path on success. Concurrent requests for the
  same path are therefore safe: at worst they duplicate CPU work, but the
  final file is never seen partially written.
  """

  @behaviour WatchClub.Ffmpeg.Probe

  require Logger

  @doc """
  Inspects a media file with `ffprobe` and returns the decoded JSON metadata
  (format, streams and chapters). Returns `{:error, message}` if `ffprobe` is
  missing, exits non-zero, or returns invalid JSON.
  """
  @impl true
  def probe(path) when is_binary(path) do
    args = [
      "-hide_banner",
      "-loglevel",
      "error",
      # Generous probe caps matching Jellyfin's defaults — ffmpeg's stock 5 MB
      # / 5 s limits silently miss streams in some files.
      "-probesize",
      "1G",
      "-analyzeduration",
      "200M",
      "-print_format",
      "json",
      "-show_format",
      "-show_streams",
      "-show_chapters",
      path
    ]

    with {:ok, ffprobe} <- find_executable("ffprobe"),
         {:ok, json} <- run_probe(ffprobe, args) do
      decode_probe_json(json)
    end
  end

  defp run_probe(ffprobe, args) do
    # Don't merge stderr: ffprobe writes JSON to stdout and diagnostics
    # (e.g. "Referenced QT chapter track not found") to stderr even at
    # `-loglevel error` while still exiting 0, which would corrupt the JSON.
    # The BEAM can't capture stderr separately, so on failure we rely on the
    # exit status; stderr is left to surface on the console.
    case System.cmd(ffprobe, args) do
      {json, 0} -> {:ok, json}
      {_output, status} -> {:error, "ffprobe exited with #{status}"}
    end
  end

  defp decode_probe_json(json) do
    case Jason.decode(json) do
      {:ok, metadata} -> {:ok, metadata}
      {:error, error} -> {:error, "ffprobe returned invalid JSON: #{Exception.message(error)}"}
    end
  end

  defp find_executable(name) do
    case System.find_executable(name) do
      nil -> {:error, "#{name} executable was not found"}
      path -> {:ok, path}
    end
  end

  @doc """
  Chromaprint fingerprint of the first audio track, over `seconds` from
  `from_seconds`. ffmpeg decodes the audio for Chromaprint's `fpcalc`, which
  has no option to start further in.
  """
  @impl true
  def audio_fingerprint(path, from_seconds, seconds) do
    pipeline =
      ~S(ffmpeg -nostdin -v error -ss "$2" -t "$3" -i "$1" -map 0:a:0 -ac 1 -ar 11025 -f s16le - ) <>
        ~S(| fpcalc -raw -format s16le -rate 11025 -channels 1 -length "$3" -)

    # pipefail: fpcalc would succeed on the audio ffmpeg decoded before failing
    case System.cmd(
           "bash",
           [
             "-c",
             "set -o pipefail; " <> pipeline,
             "bash",
             path,
             seconds(from_seconds),
             seconds(seconds)
           ],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        ["FINGERPRINT=" <> points] = Regex.run(~r/^FINGERPRINT=.*$/m, output)
        {:ok, points |> String.split(",") |> Enum.map(&String.to_integer/1)}

      {output, status} ->
        {:error, "ffmpeg | fpcalc exited with #{status}: #{output}"}
    end
  end

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

    run_command(args, tmp_path, job)
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

    run_command(args, tmp_path, job)
  end

  defp run_ffmpeg(%{type: :subtitle} = job) do
    File.mkdir_p!(Path.dirname(job.output_path))
    tmp_path = tmp_path(job.output_path)

    # Without an encoding, FFmpeg reads text subtitles as UTF-8
    character_encoding_args =
      if job.character_encoding, do: ["-sub_charenc", job.character_encoding], else: []

    args =
      ["-hide_banner", "-loglevel", "error", "-y"] ++
        character_encoding_args ++
        [
          "-i",
          job.source_path,
          "-map",
          "0:#{job.stream_index}",
          "-c:s",
          "webvtt",
          "-f",
          "webvtt",
          tmp_path
        ]

    run_command(args, tmp_path, job)
  end

  defp run_command(args, tmp_path, job) do
    Logger.debug("Running HLS ffmpeg job: ffmpeg #{Enum.join(args, " ")}")

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_output, 0} ->
        File.rename!(tmp_path, job.output_path)
        {:ok, job.output_path}

      {output, status} ->
        File.rm(tmp_path)
        {:error, "ffmpeg exited with #{status} for #{job.source_path}: #{String.trim(output)}"}
    end
  rescue
    exception ->
      File.rm(tmp_path)
      {:error, "ffmpeg failed for #{job.source_path}: #{Exception.message(exception)}"}
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
