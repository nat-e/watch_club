defmodule WatchClub.Media.ImportPipeline.ExtractStructure do
  @moduledoc """
  Inspects the candidate's bytes (and extension) to produce its `MediaStructure`
  — container, duration, tracks. Dispatches by `configuration.media_type`:
  videos and audiobooks go through `ffprobe`; ebooks use the file extension
  only.
  """

  alias WatchClub.Media.ImportConfiguration
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.Outcome

  alias WatchClub.Media.ImportPipeline.Candidate.MediaStructure

  alias WatchClub.Media.ImportPipeline.Candidate.MediaStructure.{
    AudioTrack,
    TextTrack,
    VideoTrack
  }

  alias __MODULE__.Sidecars

  @stage "extract_structure"

  def apply(%Candidate{} = candidate, %ImportConfiguration{media_type: :video}),
    do: probe_video(candidate)

  def apply(%Candidate{} = candidate, %ImportConfiguration{media_type: :audiobook}),
    do: probe_audiobook(candidate)

  def apply(%Candidate{} = candidate, %ImportConfiguration{media_type: :ebook}),
    do: probe_ebook(candidate)

  defp probe_video(candidate) do
    with {:ok, metadata} <- run_ffprobe(candidate.path),
         {:ok, structure} <- build_video_structure(metadata) do
      {:ok, Sidecars.append(%{candidate | media_structure: structure})}
    else
      {:error, message} -> {:error, fail(candidate, message)}
    end
  end

  defp probe_audiobook(candidate) do
    with {:ok, metadata} <- run_ffprobe(candidate.path),
         {:ok, structure} <- build_audiobook_structure(metadata) do
      {:ok, %{candidate | media_structure: structure}}
    else
      {:error, message} -> {:error, fail(candidate, message)}
    end
  end

  defp probe_ebook(candidate) do
    structure = %MediaStructure{
      container: candidate.extension |> String.trim_leading(".") |> empty_to_nil()
    }

    {:ok, %{candidate | media_structure: structure}}
  end

  defp fail(candidate, message) do
    %{
      candidate
      | outcome: %Outcome{
          status: :failed,
          message: "#{Path.basename(candidate.path)}: #{message}",
          metadata: %{stage: @stage}
        }
    }
  end

  defp run_ffprobe(path) do
    args = [
      "-v",
      "error",
      "-print_format",
      "json",
      "-show_format",
      "-show_streams",
      path
    ]

    with {:ok, ffprobe} <- find_ffprobe() do
      case System.cmd(ffprobe, args, stderr_to_stdout: true) do
        {json, 0} ->
          case Jason.decode(json) do
            {:ok, metadata} ->
              {:ok, metadata}

            {:error, error} ->
              {:error, "ffprobe returned invalid JSON: #{Exception.message(error)}"}
          end

        {output, status} ->
          {:error, "ffprobe exited with #{status}: #{String.trim(output)}"}
      end
    end
  end

  defp find_ffprobe do
    case System.find_executable("ffprobe") do
      nil -> {:error, "ffprobe executable was not found"}
      path -> {:ok, path}
    end
  end

  defp build_video_structure(%{"streams" => streams, "format" => format}) do
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

  defp build_video_structure(_metadata), do: {:error, "ffprobe output was incomplete"}

  defp build_audiobook_structure(%{"streams" => streams, "format" => format}) do
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

  defp build_audiobook_structure(_metadata), do: {:error, "ffprobe output was incomplete"}

  defp video_tracks(streams) do
    streams
    |> Enum.filter(&(&1["codec_type"] == "video"))
    |> Enum.map(fn stream ->
      %VideoTrack{
        stream_index: stream["index"],
        codec: stream["codec_name"],
        width: stream["width"],
        height: stream["height"],
        frame_rate: frame_rate(stream["avg_frame_rate"] || stream["r_frame_rate"]),
        bit_rate: parse_int(stream["bit_rate"]) || parse_int(get_in(stream, ["tags", "BPS"]))
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
        forced?: get_in(stream, ["disposition", "forced"]) == 1
      }
    end)
  end

  defp stream_duration(streams) do
    streams
    |> Enum.find_value(fn stream -> parse_float(stream["duration"]) end)
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
  defp parse_float(value) when is_integer(value), do: value / 1

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

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value
end
