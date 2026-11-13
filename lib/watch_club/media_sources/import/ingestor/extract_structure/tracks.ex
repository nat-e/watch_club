defmodule WatchClub.MediaSources.Import.Ingestor.ExtractStructure.Tracks do
  @moduledoc """
  Builds a `MediaStructure` from decoded `ffprobe` JSON metadata.

  Pure functions over the JSON shape — no I/O, no subprocess. Two entry points:
  `for_video/1` for video files (requires at least one video stream) and
  `for_audiobook/1` for audiobooks (requires at least one audio stream). Both
  return `{:error, message}` when the required streams are missing or the
  metadata shape is incomplete.
  """

  alias WatchClub.MediaSources.Import.Candidate.MediaStructure

  alias WatchClub.MediaSources.Import.Candidate.MediaStructure.{
    AudioTrack,
    TextTrack,
    VideoTrack
  }

  def for_video(%{"streams" => streams, "format" => format}) do
    video_tracks = video_tracks(streams)

    if video_tracks == [] do
      {:error, "ffprobe found no video tracks"}
    else
      structure = %MediaStructure{
        container: format["format_name"],
        duration_seconds: parse_float(format["duration"]) || stream_duration(streams),
        bit_rate: parse_int(format["bit_rate"]) || video_bit_rate(video_tracks),
        video_tracks: video_tracks,
        audio_tracks: audio_tracks(streams),
        text_tracks: text_tracks(streams)
      }

      {:ok, structure}
    end
  end

  def for_video(_metadata), do: {:error, "ffprobe output was incomplete"}

  def for_audiobook(%{"streams" => streams, "format" => format}) do
    audio_tracks = audio_tracks(streams)

    if audio_tracks == [] do
      {:error, "ffprobe found no audio tracks"}
    else
      structure = %MediaStructure{
        container: format["format_name"],
        duration_seconds: parse_float(format["duration"]) || stream_duration(streams),
        bit_rate: parse_int(format["bit_rate"]),
        audio_tracks: audio_tracks
      }

      {:ok, structure}
    end
  end

  def for_audiobook(_metadata), do: {:error, "ffprobe output was incomplete"}

  defp video_tracks(streams) do
    streams
    |> Enum.filter(&(&1["codec_type"] == "video"))
    |> Enum.map(fn stream ->
      %VideoTrack{
        stream_index: stream["index"],
        codec: stream["codec_name"],
        profile: stream["profile"],
        level: level(stream["level"]),
        width: stream["width"],
        height: stream["height"],
        frame_rate: frame_rate(stream["avg_frame_rate"] || stream["r_frame_rate"]),
        bit_rate: parse_int(stream["bit_rate"]) || parse_int(get_in(stream, ["tags", "BPS"])),
        default?: get_in(stream, ["disposition", "default"]) == 1
      }
    end)
  end

  defp audio_tracks(streams) do
    streams
    |> Enum.filter(&(&1["codec_type"] == "audio"))
    |> Enum.map(fn stream ->
      %AudioTrack{
        stream_index: stream["index"],
        codec: stream["codec_name"],
        language: get_in(stream, ["tags", "language"]),
        title: get_in(stream, ["tags", "title"]),
        channels: stream["channels"],
        default?: get_in(stream, ["disposition", "default"]) == 1
      }
    end)
  end

  defp text_tracks(streams) do
    streams
    |> Enum.filter(&(&1["codec_type"] == "subtitle"))
    |> Enum.map(fn stream ->
      %TextTrack{
        stream_index: stream["index"],
        codec: stream["codec_name"],
        language: get_in(stream, ["tags", "language"]),
        title: get_in(stream, ["tags", "title"]),
        default?: get_in(stream, ["disposition", "default"]) == 1,
        forced?: get_in(stream, ["disposition", "forced"]) == 1,
        sdh?: get_in(stream, ["disposition", "hearing_impaired"]) == 1
      }
    end)
  end

  # ffprobe reports an unknown level as -99
  defp level(-99), do: nil
  defp level(level), do: level

  defp stream_duration(streams) do
    Enum.find_value(streams, fn stream -> parse_float(stream["duration"]) end)
  end

  defp video_bit_rate([%VideoTrack{bit_rate: bit_rate} | _]), do: bit_rate
  defp video_bit_rate(_tracks), do: nil

  defp frame_rate(nil), do: nil
  defp frame_rate("0/0"), do: nil

  defp frame_rate(value) when is_binary(value) do
    case String.split(value, "/") do
      [numerator, denominator] ->
        numerator = parse_float(numerator)
        denominator = parse_float(denominator)

        if numerator && denominator && denominator != 0 do
          numerator / denominator
        end

      [value] ->
        parse_float(value)
    end
  end

  defp frame_rate(value), do: parse_float(value)

  defp parse_float(nil), do: nil
  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value * 1.0

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _rest} -> float
      :error -> nil
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _rest} -> integer
      :error -> nil
    end
  end
end
