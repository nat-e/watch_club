defmodule WatchClub.Media.ImportPipeline.ExtractStructure do
  @moduledoc false

  alias WatchClub.Media.ImportPipeline.Candidate

  alias WatchClub.Media.ImportPipeline.Candidate.{
    AudioTrackProbe,
    TextTrackSpec,
    VideoTrackProbe
  }

  alias WatchClub.Media.ImportPipeline.Candidate.Probe, as: CandidateProbe

  @probe_concurrency 2
  @supervisor __MODULE__.Supervisor

  def child_spec(_opts) do
    Supervisor.child_spec(
      {Task.Supervisor, name: @supervisor},
      id: @supervisor
    )
  end

  def stream(candidates) do
    Task.Supervisor.async_stream(
      @supervisor,
      candidates,
      __MODULE__,
      :candidate,
      [],
      max_concurrency: @probe_concurrency,
      ordered: false,
      timeout: :infinity,
      zip_input_on_exit: true
    )
    |> Stream.map(&normalize_result/1)
  end

  def candidate(%Candidate{} = candidate) do
    case candidate.media_type do
      :video -> probe_video(candidate)
      :audiobook -> probe_audiobook(candidate)
      :ebook -> probe_ebook(candidate)
    end
  rescue
    exception ->
      {:error, candidate, Exception.message(exception)}
  end

  defp normalize_result({:ok, {:ok, candidate}}), do: {:ok, candidate}
  defp normalize_result({:ok, {:error, candidate, message}}), do: {:error, candidate, message}

  defp normalize_result({:exit, {candidate, reason}}) do
    {:error, candidate, "Probe task exited: #{inspect(reason)}"}
  end

  defp normalize_result({:exit, reason}) do
    {:fatal, "Probe task exited before returning a candidate: #{inspect(reason)}"}
  end

  defp probe_video(candidate) do
    with {:ok, metadata} <- run_ffprobe(candidate.path),
         {:ok, probe} <- build_video_probe(metadata, candidate) do
      {:ok, %{candidate | probe: probe}}
    else
      {:error, message} -> {:error, candidate, message_for(candidate, message)}
    end
  end

  defp probe_audiobook(candidate) do
    with {:ok, metadata} <- run_ffprobe(candidate.path),
         {:ok, probe} <- build_audiobook_probe(metadata) do
      {:ok, %{candidate | probe: probe}}
    else
      {:error, message} -> {:error, candidate, message_for(candidate, message)}
    end
  end

  defp probe_ebook(candidate) do
    probe = %CandidateProbe{
      media_type: :ebook,
      container: candidate.extension |> String.trim_leading(".") |> empty_to_nil()
    }

    {:ok, %{candidate | probe: probe}}
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

  defp build_video_probe(%{"streams" => streams, "format" => format}, candidate) do
    video_tracks = video_tracks(streams)

    if video_tracks == [] do
      {:error, "ffprobe found no video tracks"}
    else
      probe = %CandidateProbe{
        media_type: :video,
        container: format["format_name"],
        duration_seconds: parse_float(format["duration"]) || stream_duration(streams),
        bit_rate: parse_int(format["bit_rate"]) || video_bit_rate(video_tracks),
        video_tracks: video_tracks,
        audio_tracks: audio_tracks(streams),
        text_tracks: text_tracks(streams) ++ candidate.sidecar_text_tracks
      }

      {:ok, probe}
    end
  end

  defp build_video_probe(_metadata, _candidate), do: {:error, "ffprobe output was incomplete"}

  defp build_audiobook_probe(%{"streams" => streams, "format" => format}) do
    audio_tracks = audio_tracks(streams)

    if audio_tracks == [] do
      {:error, "ffprobe found no audio tracks"}
    else
      probe = %CandidateProbe{
        media_type: :audiobook,
        container: format["format_name"],
        duration_seconds: parse_float(format["duration"]) || stream_duration(streams),
        bit_rate: parse_int(format["bit_rate"]),
        audio_tracks: audio_tracks
      }

      {:ok, probe}
    end
  end

  defp build_audiobook_probe(_metadata), do: {:error, "ffprobe output was incomplete"}

  defp video_tracks(streams) do
    streams
    |> Enum.filter(&(&1["codec_type"] == "video"))
    |> Enum.map(fn stream ->
      %VideoTrackProbe{
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
      %AudioTrackProbe{
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
      %TextTrackSpec{
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

  defp video_bit_rate([%VideoTrackProbe{bit_rate: bit_rate} | _]), do: bit_rate
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

  defp message_for(candidate, message),
    do: "#{Path.basename(candidate.path)}: #{message}"

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value
end
