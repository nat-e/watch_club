defmodule WatchClub.Playback.Stream.Actions.Helpers do
  @moduledoc false

  alias WatchClub.Playback.Session
  alias WatchClub.Playback.Stream
  alias WatchClub.Playback.Stream.{Playlist, QualityLadder}
  alias WatchClub.SystemActor

  @segment_duration 6.0
  @supported_subtitle_codecs ~w(subrip webvtt ass ssa)

  @doc """
  Loads the Stream by id and authorizes the actor by reading the backing
  Session as that actor. If the actor cannot read the Session, the error
  surfaces here.
  """
  def fetch_authorized_stream(stream_id, actor) do
    with {:ok, stream} <- read_stream(stream_id),
         :ok <- authorize_against_session(stream, actor) do
      {:ok, stream}
    end
  end

  @doc "The configured HLS segment duration in seconds."
  def segment_duration, do: @segment_duration

  @doc "Number of segments needed to cover the source's duration."
  def segment_count(stream) do
    stream
    |> duration()
    |> Kernel./(@segment_duration)
    |> Float.ceil()
    |> trunc()
  end

  @doc "Source duration in seconds, read from the cached Media graph."
  def duration(stream), do: stream.media.video.duration_seconds

  @doc "Player display title."
  def title(stream), do: Path.basename(stream.media.path)

  @doc "Primary video track of the cached Media graph."
  def primary_video_track(stream) do
    case stream.media.video.video_tracks do
      [track | _rest] -> track
      [] -> nil
    end
  end

  @doc "Video metadata in the shape the playlist serializer expects."
  def video_view(stream) do
    track = primary_video_track(stream)

    %{
      codec: track.codec,
      width: track.width,
      height: track.height,
      frame_rate: track.frame_rate,
      bit_rate: track.bit_rate
    }
  end

  @doc "Audio tracks in the shape the playlist serializer expects."
  def audio_tracks(stream) do
    stream.media.video.audio_tracks
    |> Enum.with_index()
    |> Enum.map(fn {track, index} ->
      language = track.language || "und"

      %{
        id: "a#{index}",
        stream_index: track.stream_index,
        codec: track.codec,
        language: language,
        label: track_label(language, track.title, "Audio #{index + 1}"),
        channels: track.channels || 2,
        default?: track.default?
      }
    end)
    |> ensure_one_default_track()
  end

  @doc "Subtitle tracks (HLS-supported, embedded only) in playlist-serializer shape."
  def subtitle_tracks(stream) do
    stream.media.video.text_tracks
    |> Enum.filter(&supported_text_track?/1)
    |> Enum.with_index()
    |> Enum.map(fn {track, index} ->
      language = track.language || "und"

      %{
        id: "s#{index}",
        stream_index: track.stream_index,
        codec: track.codec,
        language: language,
        label: track_label(language, track.title, "Subtitle #{index + 1}"),
        default?: track.default?,
        file_name: "s#{index}.vtt"
      }
    end)
  end

  @doc "Qualities built from the primary video track dimensions and bit rate."
  def qualities(stream) do
    track = primary_video_track(stream)
    QualityLadder.build(track.width, track.height, track.bit_rate)
  end

  def find_quality(stream, id) do
    case Enum.find(qualities(stream), &(&1.id == id)) do
      nil -> {:error, :not_found}
      quality -> {:ok, quality}
    end
  end

  def find_audio_track(stream, id) do
    case Enum.find(audio_tracks(stream), &(&1.id == id)) do
      nil -> {:error, :not_found}
      track -> {:ok, track}
    end
  end

  def find_subtitle_track(stream, id) do
    case Enum.find(subtitle_tracks(stream), &(&1.id == id)) do
      nil -> {:error, :not_found}
      track -> {:ok, track}
    end
  end

  def parse_segment_name(segment_name) do
    case Regex.run(~r/^seg_(\d+)\.ts$/, segment_name) do
      [_segment_name, index] -> {:ok, String.to_integer(index)}
      _no_match -> {:error, :invalid_segment}
    end
  end

  def validate_segment_index(stream, index) do
    if index >= 0 and index < segment_count(stream) do
      :ok
    else
      {:error, :not_found}
    end
  end

  def segment_duration_at(stream, index) do
    remaining = duration(stream) - index * @segment_duration
    min(@segment_duration, max(remaining, 0.1))
  end

  def video_segment_path(stream, quality, index) do
    Path.join([
      stream.output_dir,
      "video",
      quality.id,
      "seg_#{Playlist.pad_segment(index)}.ts"
    ])
  end

  def audio_segment_path(stream, track, index) do
    Path.join([
      stream.output_dir,
      "audio",
      track.id,
      "seg_#{Playlist.pad_segment(index)}.ts"
    ])
  end

  def subtitle_file_path(stream, track) do
    Path.join([stream.output_dir, "subtitles", track.id, track.file_name])
  end

  def cached?(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > 0 -> true
      _other -> false
    end
  end

  defp read_stream(stream_id) do
    case Ash.get(Stream, stream_id, actor: SystemActor.actor()) do
      {:ok, stream} -> {:ok, stream}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp authorize_against_session(stream, actor) do
    case Ash.get(Session, stream.session_id, actor: actor) do
      {:ok, _session} -> :ok
      {:error, %Ash.Error.Forbidden{} = error} -> {:error, error}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp supported_text_track?(track) do
    is_nil(track.sidecar_path) and track.codec in @supported_subtitle_codecs
  end

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
end
