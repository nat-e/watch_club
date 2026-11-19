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

  alias WatchClub.Ffmpeg.MatroskaCues

  require Logger

  # Keyframe times are rounded to the microsecond. Video segments bound their frames a millisecond
  # before their times, less than a frame, so that a keyframe lands on the right side.
  @frame_margin 0.001

  @aac_sample_rate 48_000
  @aac_frame_samples 1024
  # Encoded past each end of an audio segment: an AAC frame blends with its neighbours, and the
  # first frame of a run is silent
  @aac_margin 2 * @aac_frame_samples

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

  @doc """
  The keyframes of the video stream at `stream_index`, in order, each with its time in seconds
  from the file's start, as `-ss` counts them, and the bytes of the stream's frames from it to
  the next keyframe. They come from the Cues of a Matroska file, and otherwise from every packet
  `ffprobe` reads in the whole file. Returns `{:error, message}` when `ffprobe` fails or finds
  no keyframe.
  """
  @impl true
  def keyframes(path, stream_index) when is_binary(path) do
    with {:ok, ffprobe} <- find_executable("ffprobe"),
         {:ok, file} <- probe_stated_bit_rates(ffprobe, path),
         {:ok, keyframes} <- read_keyframes(ffprobe, path, stream_index, file) do
      {:ok,
       Enum.map(keyframes, fn {time, bytes} ->
         {Float.round(time - file.start_time, 6), bytes}
       end)}
    end
  end

  # The file's start and end, in seconds of its timestamps, and the bit rates it states for the
  # streams its frames hold, by index, nil for a stream that doesn't. mkvmerge and MakeMKV state
  # them in BPS tags, which ffprobe suffixes with the tag's language when it has one. Otherwise
  # the decoder gives the bit rate of a constant bit rate codec, or of a stream's first frame.
  defp probe_stated_bit_rates(ffprobe, path) do
    args = [
      "-v",
      "error",
      "-show_entries",
      "format=start_time,duration:stream=index,codec_type,bit_rate:stream_tags" <>
        ":stream_disposition=attached_pic",
      "-of",
      "json",
      path
    ]

    with {:ok, json} <- run_probe(ffprobe, args),
         {:ok, %{"format" => format, "streams" => streams}} <- decode_probe_json(json) do
      # No start time when no stream has a timestamp
      start_time = parse_number(format["start_time"]) || 0.0
      duration = parse_number(format["duration"])

      # Attachments, such as fonts and cover pictures, aren't frames
      bit_rates =
        for stream <- streams,
            stream["codec_type"] != "attachment",
            stream["disposition"]["attached_pic"] != 1,
            into: %{} do
          tags = stream["tags"] || %{}

          bps =
            tags["BPS"] ||
              Enum.find_value(tags, fn {name, value} ->
                if String.starts_with?(name, "BPS-"), do: value
              end)

          {stream["index"], parse_number(bps || stream["bit_rate"])}
        end

      {:ok,
       %{
         start_time: start_time,
         end_time: duration && start_time + duration,
         bit_rates: bit_rates
       }}
    end
  end

  defp parse_number(nil), do: nil

  defp parse_number(string) do
    case Float.parse(string) do
      {number, ""} -> number
      _not_a_number -> nil
    end
  end

  defp read_keyframes(ffprobe, path, stream_index, file) do
    case keyframes_from_cues(path, stream_index, file) do
      {:ok, keyframes} -> {:ok, keyframes}
      :error -> scan_keyframes(ffprobe, path, stream_index)
    end
  end

  # The Cues give where each keyframe starts in the file, so the bytes from one keyframe to the
  # next hold every stream's frames and the container's headers.
  defp keyframes_from_cues(path, stream_index, file) do
    with {:ok, keyframes} <- MatroskaCues.keyframes(path, stream_index) do
      {:ok, without_other_streams(keyframes, stream_index, file) || keyframes}
    end
  end

  # Takes everything but the video out at its average bit rate: the file's, from the Cues, minus
  # the one it states for the video. Stated bit rates are trusted only when every stream has one
  # and they add up to the file's: ffmpeg keeps them when it re-encodes a stream. nil otherwise,
  # and every byte then counts as video: the import never reads the whole file.
  defp without_other_streams(
         [{first_time, _bytes} | _] = keyframes,
         stream_index,
         %{bit_rates: bit_rates, end_time: end_time}
       ) do
    with true <- is_float(end_time) and end_time > first_time,
         true <- Enum.all?(Map.values(bit_rates), &is_float/1),
         {times, interval_bytes} = Enum.unzip(keyframes),
         stated_bit_rate = bit_rates |> Map.values() |> Enum.sum(),
         file_bit_rate = Enum.sum(interval_bytes) * 8 / (end_time - first_time),
         true <- abs(stated_bit_rate - file_bit_rate) <= file_bit_rate * 0.03 do
      other_bytes_per_second = (file_bit_rate - bit_rates[stream_index]) / 8
      durations = Enum.zip_with(times, tl(times) ++ [end_time], &(&2 - &1))

      keyframes =
        Enum.zip_with([times, interval_bytes, durations], fn [time, bytes, duration] ->
          {time, round(bytes - other_bytes_per_second * duration)}
        end)

      # Every keyframe has bytes of its own
      if Enum.all?(keyframes, fn {_time, bytes} -> bytes > 0 end), do: keyframes
    else
      _untrusted -> nil
    end
  end

  # `+genpts` gives a time to packets without one, as in AVI files. Sorted by display time, as
  # segments cut them, each packet counts toward the keyframe shown at or before it.
  defp scan_keyframes(ffprobe, path, stream_index) do
    args = [
      "-v",
      "error",
      "-fflags",
      "+genpts",
      "-select_streams",
      Integer.to_string(stream_index),
      "-show_entries",
      "packet=pts_time,size,flags",
      "-of",
      "csv=p=0",
      path
    ]

    case System.cmd(ffprobe, args) do
      {output, 0} ->
        packets =
          for line <- String.split(output, "\n", trim: true),
              [time, size, flags | _side_data] <- [String.split(line, ",")],
              {time, ""} <- [Float.parse(time)],
              {size, ""} <- [Integer.parse(size)] do
            {time, size, String.contains?(flags, "K")}
          end

        keyframes =
          packets
          |> Enum.sort_by(fn {time, _size, _keyframe?} -> time end)
          |> Enum.reduce([], fn
            {time, size, true}, [] ->
              [{time, size}]

            {time, size, true}, [{keyframe, _bytes} | _] = keyframes when time > keyframe ->
              [{time, size} | keyframes]

            {_time, size, _keyframe?}, [{keyframe, bytes} | earlier] ->
              [{keyframe, bytes + size} | earlier]

            # Before the first keyframe
            {_time, _size, false}, [] ->
              []
          end)
          |> Enum.reverse()

        case keyframes do
          [] -> {:error, "ffprobe found no keyframes"}
          keyframes -> {:ok, keyframes}
        end

      {_output, status} ->
        {:error, "ffprobe exited with #{status} while reading the keyframes"}
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
  has no option to start further in. Returns `{:error, message}` when the
  file's audio can't be decoded, and raises when ffmpeg or fpcalc is missing.
  """
  @impl true
  def audio_fingerprint(path, from_seconds, seconds) do
    for tool <- ["ffmpeg", "fpcalc"], is_nil(System.find_executable(tool)) do
      raise "#{tool} executable was not found"
    end

    pipeline =
      ~S(ffmpeg -nostdin -v error -ss "$2" -t "$3" -i "$1" -map 0:a:0 -ac 1 -ar 11025 -f s16le - ) <>
        ~S(| fpcalc -raw -format s16le -rate 11025 -channels 1 -length "$3" -)

    # pipefail: fpcalc would succeed on the audio ffmpeg decoded before failing.
    # At the lowest CPU priority, so Playback transcodes get the CPU first.
    case System.cmd(
           "nice",
           [
             "-n",
             "19",
             "bash",
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

  @doc """
  Copies the H.264 video stream at `stream_index` from `start_time` to `end_time`, in seconds of
  the file, as an MPEG-TS segment. Segments keep the file's timestamps, so consecutive ones form
  a single timeline.

  `start_time` is a keyframe, or the file's start. `end_time` is the next segment's
  `start_time`, or the end of the file.
  """
  def copy_video_segment(job) do
    run_ffmpeg(Map.put(job, :type, :video_copy))
  end

  @doc """
  Encodes the video stream at `stream_index` from `start_time` to `end_time` as an MPEG-TS
  segment of H.264 Constrained Baseline at `level`, such as 40 for level 4.0. It has the same
  frames and timestamps as `copy_video_segment/1` for the same times, and decodes from the
  keyframe at `start_time` only.
  """
  def transcode_video_segment(job) do
    run_ffmpeg(Map.put(job, :type, :video))
  end

  @doc """
  Encodes the audio from `start_time` to `end_time`, in seconds of the file, as an MPEG-TS segment of
  AAC with the file's timestamps. An AAC encoder starts each run with a frame of silence, so each run
  encodes past both ends, then keeps the frames inside the segment: consecutive segments join
  without a gap.
  """
  def transcode_audio_segment(job) do
    run_ffmpeg(Map.put(job, :type, :audio))
  end

  def transcode_subtitle_file(job) do
    run_ffmpeg(Map.put(job, :type, :subtitle))
  end

  defp run_ffmpeg(%{type: :video_copy} = job) do
    File.mkdir_p!(Path.dirname(job.output_path))
    tmp_path = tmp_path(job.output_path)

    args = [
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      # The file's timestamps, from its start
      "-copyts",
      "-start_at_zero",
      # Starts reading on the keyframe at or before the seek time
      "-ss",
      seconds(job.start_time + @frame_margin),
      "-i",
      job.source_path,
      # With -copyts, -t would count from 0
      "-to",
      seconds(job.end_time - @frame_margin),
      "-map",
      "0:#{job.stream_index}",
      "-c:v",
      "copy",
      # Gives every keyframe the parameter sets, which an MP4 or Matroska file stores once, so
      # that a segment can start on a keyframe that isn't an IDR frame. Then keeps the frames
      # inside the segment: -to stops on a decoding time, which runs behind the display time.
      "-bsf:v",
      "h264_mp4toannexb,dump_extra=freq=keyframe," <>
        "noise=drop=lt(pts*tb\\,#{seconds(job.start_time - @frame_margin)})" <>
        "+gte(pts*tb\\,#{seconds(job.end_time - @frame_margin)})",
      "-avoid_negative_ts",
      "disabled",
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

  defp run_ffmpeg(%{type: :video} = job) do
    File.mkdir_p!(Path.dirname(job.output_path))
    tmp_path = tmp_path(job.output_path)

    # Drops the frames shown before the keyframe, which need the previous segment's frames
    filters =
      "trim=start=#{seconds(job.start_time - @frame_margin)}," <>
        "scale=#{job.width}:#{job.height},setsar=1,format=yuv420p"

    args = [
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      # The file's timestamps, from its start
      "-copyts",
      "-start_at_zero",
      # Starts decoding on the keyframe at or before the seek time, and keeps its frames
      "-noaccurate_seek",
      "-ss",
      seconds(job.start_time + @frame_margin),
      "-i",
      job.source_path,
      # With -copyts, -t would count from 0
      "-to",
      seconds(job.end_time - @frame_margin),
      "-map",
      "0:#{job.stream_index}",
      "-vf",
      filters,
      "-c:v",
      "libx264",
      "-preset",
      "ultrafast",
      # The ultrafast preset uses only the tools of Constrained Baseline
      "-profile:v",
      "baseline",
      "-level:v",
      Integer.to_string(job.level),
      "-pix_fmt",
      "yuv420p",
      "-b:v",
      bitrate(job.video_bitrate),
      "-maxrate",
      bitrate(round(job.video_bitrate * 1.2)),
      "-bufsize",
      bitrate(job.video_bitrate * 2),
      # Rounding timestamps to the frame rate would move a frame across -to, but not across -ss
      "-enc_time_base:v",
      "1/90000",
      "-avoid_negative_ts",
      "disabled",
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

    first_sample = aac_frame_boundary(job.start_time)
    end_sample = aac_frame_boundary(job.end_time)
    input_start = max(first_sample - @aac_margin, 0)
    half_frame = div(@aac_frame_samples, 2)

    args = [
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      # The file's timestamps, from its start
      "-copyts",
      "-start_at_zero",
      "-ss",
      sample_time(input_start),
      "-i",
      job.source_path,
      # With -copyts, -t would count from 0
      "-to",
      sample_time(end_sample + @aac_margin),
      "-map",
      "0:#{job.stream_index}",
      "-vn",
      "-sn",
      # Timestamps counted in samples from the first one, so every frame falls on a boundary
      "-af",
      "aresample=#{@aac_sample_rate},aresample=async=1:first_pts=#{input_start}",
      "-c:a",
      "aac",
      "-ac",
      "2",
      "-b:a",
      "160k",
      # Keeps the frames inside the segment
      "-bsf:a",
      "noise=drop=lt(pts*tb\\,#{sample_time(first_sample - half_frame)})" <>
        "+gte(pts*tb\\,#{sample_time(end_sample - half_frame)})",
      "-avoid_negative_ts",
      "disabled",
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

  # The AAC frame boundary closest to `seconds`, in samples. Every audio segment cuts on these.
  defp aac_frame_boundary(seconds),
    do: round(seconds * @aac_sample_rate / @aac_frame_samples) * @aac_frame_samples

  defp sample_time(samples),
    do: :erlang.float_to_binary(samples / @aac_sample_rate, decimals: 6)

  defp seconds(value) when is_integer(value), do: Integer.to_string(value)
  defp seconds(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 6)

  defp bitrate(value) when is_integer(value), do: "#{value}"
  defp bitrate(value) when is_float(value), do: value |> round() |> bitrate()
end
