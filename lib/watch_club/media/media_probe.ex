defmodule WatchClub.Media.MediaProbe do
  @moduledoc """
  ffprobe wrapper that extracts playback metadata from a source media file.

  Returns the duration, the source video stream's codec/dimensions/frame rate,
  and the list of audio and subtitle tracks suitable for HLS playback.
  """

  defmodule Video do
    @moduledoc false
    @enforce_keys [:codec, :width, :height, :frame_rate, :bit_rate]
    defstruct [:codec, :width, :height, :frame_rate, :bit_rate]

    @type t :: %__MODULE__{
            codec: String.t() | nil,
            width: integer() | nil,
            height: integer() | nil,
            frame_rate: float(),
            bit_rate: integer() | nil
          }
  end

  defmodule AudioTrack do
    @moduledoc false
    @enforce_keys [:id, :stream_index, :codec, :language, :label, :channels, :default?]
    defstruct [:id, :stream_index, :codec, :language, :label, :channels, :default?]

    @type t :: %__MODULE__{
            id: String.t(),
            stream_index: integer(),
            codec: String.t() | nil,
            language: String.t(),
            label: String.t(),
            channels: integer(),
            default?: boolean()
          }
  end

  defmodule SubtitleTrack do
    @moduledoc false
    @enforce_keys [:id, :stream_index, :codec, :language, :label, :default?, :file_name]
    defstruct [:id, :stream_index, :codec, :language, :label, :default?, :file_name]

    @type t :: %__MODULE__{
            id: String.t(),
            stream_index: integer(),
            codec: String.t() | nil,
            language: String.t(),
            label: String.t(),
            default?: boolean(),
            file_name: String.t()
          }
  end

  defmodule Metadata do
    @moduledoc false
    @enforce_keys [:title, :duration, :video, :audio_tracks, :subtitle_tracks]
    defstruct [:title, :duration, :video, :audio_tracks, :subtitle_tracks]

    @type t :: %__MODULE__{
            title: String.t(),
            duration: float(),
            video: WatchClub.Media.MediaProbe.Video.t(),
            audio_tracks: [WatchClub.Media.MediaProbe.AudioTrack.t()],
            subtitle_tracks: [WatchClub.Media.MediaProbe.SubtitleTrack.t()]
          }
  end

  @supported_subtitle_codecs ~w(subrip webvtt ass ssa)

  @spec probe(String.t()) :: {:ok, Metadata.t()} | {:error, String.t()}
  def probe(source_path) do
    args = [
      "-v",
      "error",
      "-print_format",
      "json",
      "-show_format",
      "-show_streams",
      source_path
    ]

    case System.cmd("ffprobe", args, stderr_to_stdout: true) do
      {json, 0} ->
        {:ok, build_metadata(Jason.decode!(json), source_path)}

      {output, status} ->
        {:error, "ffprobe exited with #{status}: #{String.trim(output)}"}
    end
  rescue
    exception ->
      {:error, Exception.message(exception)}
  end

  defp build_metadata(%{"streams" => streams, "format" => format}, source_path) do
    video_stream = Enum.find(streams, &(&1["codec_type"] == "video"))
    duration = parse_float(format["duration"]) || stream_duration(video_stream)

    source_bit_rate =
      parse_int(video_stream["bit_rate"]) || parse_int(get_in(video_stream, ["tags", "BPS"]))

    audio_tracks =
      streams
      |> Enum.filter(&(&1["codec_type"] == "audio"))
      |> Enum.with_index()
      |> Enum.map(fn {stream, index} -> audio_track(stream, index) end)
      |> ensure_one_default_track()

    subtitle_tracks =
      streams
      |> Enum.filter(&supported_subtitle?/1)
      |> Enum.with_index()
      |> Enum.map(fn {stream, index} -> subtitle_track(stream, index) end)

    %Metadata{
      title: get_in(format, ["tags", "title"]) || Path.basename(source_path),
      duration: duration,
      video: %Video{
        codec: video_stream["codec_name"],
        width: video_stream["width"],
        height: video_stream["height"],
        frame_rate: frame_rate(video_stream["avg_frame_rate"] || video_stream["r_frame_rate"]),
        bit_rate: source_bit_rate
      },
      audio_tracks: audio_tracks,
      subtitle_tracks: subtitle_tracks
    }
  end

  defp audio_track(stream, index) do
    language = get_in(stream, ["tags", "language"]) || "und"
    title = get_in(stream, ["tags", "title"])

    %AudioTrack{
      id: "a#{index}",
      stream_index: stream["index"],
      codec: stream["codec_name"],
      language: language,
      label: track_label(language, title, "Audio #{index + 1}"),
      channels: stream["channels"] || 2,
      default?: get_in(stream, ["disposition", "default"]) == 1
    }
  end

  defp subtitle_track(stream, index) do
    language = get_in(stream, ["tags", "language"]) || "und"
    title = get_in(stream, ["tags", "title"])

    %SubtitleTrack{
      id: "s#{index}",
      stream_index: stream["index"],
      codec: stream["codec_name"],
      language: language,
      label: track_label(language, title, "Subtitle #{index + 1}"),
      default?: get_in(stream, ["disposition", "default"]) == 1,
      file_name: "s#{index}.vtt"
    }
  end

  defp supported_subtitle?(%{"codec_type" => "subtitle", "codec_name" => codec}),
    do: codec in @supported_subtitle_codecs

  defp supported_subtitle?(_stream), do: false

  defp ensure_one_default_track([]), do: []

  defp ensure_one_default_track(tracks) do
    if Enum.any?(tracks, & &1.default?) do
      tracks
    else
      [first | rest] = tracks
      [%{first | default?: true} | rest]
    end
  end

  defp track_label(language, title, fallback) do
    language_name = language_name(language)

    case title do
      nil -> "#{language_name} — #{fallback}"
      "" -> "#{language_name} — #{fallback}"
      title -> "#{language_name} — #{title}"
    end
  end

  defp language_name(language) when is_binary(language) do
    case WatchClub.Cldr.Language.to_string(language) do
      {:ok, name} ->
        name

      _error ->
        case Cldr.Locale.canonical_language_tag(language, WatchClub.Cldr) do
          {:ok, tag} ->
            case WatchClub.Cldr.Language.to_string(tag) do
              {:ok, name} -> name
              _error -> String.upcase(language)
            end

          {:error, _reason} ->
            String.upcase(language)
        end
    end
  end

  defp frame_rate(nil), do: 24.0
  defp frame_rate("0/0"), do: 24.0

  defp frame_rate(value) when is_binary(value) do
    case String.split(value, "/") do
      [numerator, denominator] ->
        numerator = parse_float(numerator) || 0.0
        denominator = parse_float(denominator) || 1.0

        if denominator == 0.0 do
          24.0
        else
          numerator / denominator
        end

      _other ->
        parse_float(value) || 24.0
    end
  end

  defp stream_duration(nil), do: 0.0

  defp stream_duration(stream) do
    parse_float(stream["duration"]) || parse_float(get_in(stream, ["tags", "DURATION"])) || 0.0
  end

  defp parse_float(nil), do: nil
  defp parse_float(value) when is_integer(value), do: value / 1
  defp parse_float(value) when is_float(value), do: value

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
