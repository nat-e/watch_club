defmodule WatchClub.Playback.HlsSession do
  @moduledoc """
  Prototype HLS session manager for `/play`.

  A session owns a temporary on-disk segment cache. Playlists are generated
  virtually from ffprobe metadata, and requested media segments are transcoded on
  demand through `WatchClub.Playback.FfmpegTranscoder`.
  """

  use GenServer

  alias ExM3U8.MediaPlaylist
  alias ExM3U8.MediaPlaylist.Info, as: MediaPlaylistInfo
  alias ExM3U8.MultivariantPlaylist
  alias ExM3U8.Tags.{Discontinuity, Media, Segment, Stream}
  alias WatchClub.Playback.FfmpegTranscoder

  require Logger

  @source_path Path.expand(
                 "media/sonarr/Friends (1994) {tvdb-79168}/Season 01/Friends (1994) - S01E01 - The One Where Monica Gets a Roommate [WEBDL-1080p][EAC3 5.1][h265]-FTMVHD.mkv",
                 File.cwd!()
               )
  @cache_root Path.expand("tmp/watch_club_hls", File.cwd!())
  @segment_duration 6.0
  @idle_timeout_ms :timer.minutes(30)
  @stale_session_age_seconds 6 * 60 * 60
  @call_timeout_ms 180_000

  def start_session do
    cleanup_stale_sessions()
    id = new_session_id()

    case GenServer.start(__MODULE__, %{id: id}, name: via(id)) do
      {:ok, pid} -> {:ok, GenServer.call(pid, :describe, @call_timeout_ms)}
      {:error, {:already_started, pid}} -> {:ok, GenServer.call(pid, :describe, @call_timeout_ms)}
      {:error, {:already_registered, _pid}} -> start_session()
      {:error, reason} -> {:error, reason}
    end
  end

  def describe(session_id) do
    with {:ok, pid} <- fetch(session_id) do
      {:ok, GenServer.call(pid, :describe, @call_timeout_ms)}
    end
  end

  def master_playlist(session_id) do
    call_session(session_id, :master_playlist)
  end

  def video_playlist(session_id, variant_id) do
    call_session(session_id, {:video_playlist, variant_id})
  end

  def audio_playlist(session_id, track_id) do
    call_session(session_id, {:audio_playlist, track_id})
  end

  def subtitle_playlist(session_id, track_id) do
    call_session(session_id, {:subtitle_playlist, track_id})
  end

  def video_segment(session_id, variant_id, segment_name) do
    call_session(session_id, {:video_segment, variant_id, segment_name})
  end

  def audio_segment(session_id, track_id, segment_name) do
    call_session(session_id, {:audio_segment, track_id, segment_name})
  end

  def subtitle_file(session_id, track_id, file_name) do
    call_session(session_id, {:subtitle_file, track_id, file_name})
  end

  def status(session_id) do
    call_session(session_id, :status)
  end

  def stop(session_id) do
    with {:ok, pid} <- fetch(session_id) do
      GenServer.stop(pid, :normal)
      :ok
    end
  end

  @impl true
  def init(%{id: id}) do
    File.mkdir_p!(@cache_root)

    with :ok <- ensure_source_exists(),
         {:ok, metadata} <- probe_source(@source_path) do
      output_dir = Path.join(@cache_root, id)
      File.mkdir_p!(output_dir)
      Process.send_after(self(), :idle_cleanup, @idle_timeout_ms)

      {:ok,
       %{
         id: id,
         source_path: @source_path,
         output_dir: output_dir,
         metadata: metadata,
         started_at: DateTime.utc_now(),
         last_accessed_at: System.monotonic_time(:millisecond),
         generated_segments: 0,
         last_error: nil
       }}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call(:describe, _from, state) do
    {:reply, describe_state(state), touch(state)}
  end

  def handle_call(:master_playlist, _from, state) do
    {:reply, {:ok, build_master_playlist(state)}, touch(state)}
  end

  def handle_call({:video_playlist, variant_id}, _from, state) do
    case find_quality(state, variant_id) do
      {:ok, quality} -> {:reply, {:ok, build_media_playlist(state, quality)}, touch(state)}
      :error -> {:reply, {:error, :not_found}, touch(state)}
    end
  end

  def handle_call({:audio_playlist, track_id}, _from, state) do
    case find_audio_track(state, track_id) do
      {:ok, track} -> {:reply, {:ok, build_audio_playlist(state, track)}, touch(state)}
      :error -> {:reply, {:error, :not_found}, touch(state)}
    end
  end

  def handle_call({:subtitle_playlist, track_id}, _from, state) do
    case find_subtitle_track(state, track_id) do
      {:ok, track} -> {:reply, {:ok, build_subtitle_playlist(state, track)}, touch(state)}
      :error -> {:reply, {:error, :not_found}, touch(state)}
    end
  end

  def handle_call({:video_segment, variant_id, segment_name}, _from, state) do
    result =
      with {:ok, quality} <- find_quality(state, variant_id),
           {:ok, index} <- parse_segment_name(segment_name),
           :ok <- validate_segment_index(state, index) do
        ensure_video_segment(state, quality, index)
      end

    {reply, state} = apply_segment_result(result, state)
    {:reply, reply, touch(state)}
  end

  def handle_call({:audio_segment, track_id, segment_name}, _from, state) do
    result =
      with {:ok, track} <- find_audio_track(state, track_id),
           {:ok, index} <- parse_segment_name(segment_name),
           :ok <- validate_segment_index(state, index) do
        ensure_audio_segment(state, track, index)
      end

    {reply, state} = apply_segment_result(result, state)
    {:reply, reply, touch(state)}
  end

  def handle_call({:subtitle_file, track_id, file_name}, _from, state) do
    result =
      with {:ok, track} <- find_subtitle_track(state, track_id),
           :ok <- validate_subtitle_file_name(track, file_name) do
        ensure_subtitle_file(state, track)
      end

    {reply, state} = apply_segment_result(result, state)
    {:reply, reply, touch(state)}
  end

  def handle_call(:status, _from, state) do
    {:reply, {:ok, build_status(state)}, touch(state)}
  end

  @impl true
  def handle_info(:idle_cleanup, state) do
    idle_for = System.monotonic_time(:millisecond) - state.last_accessed_at

    if idle_for >= @idle_timeout_ms do
      {:stop, :normal, state}
    else
      Process.send_after(self(), :idle_cleanup, @idle_timeout_ms - idle_for)
      {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    File.rm_rf(state.output_dir)
    :ok
  end

  defp call_session(session_id, message) do
    with {:ok, pid} <- fetch(session_id) do
      GenServer.call(pid, message, @call_timeout_ms)
    end
  end

  defp fetch(session_id) do
    case :global.whereis_name({__MODULE__, session_id}) do
      :undefined -> {:error, :not_found}
      pid -> {:ok, pid}
    end
  end

  defp via(session_id), do: {:global, {__MODULE__, session_id}}

  defp ensure_source_exists do
    if File.exists?(@source_path) do
      :ok
    else
      {:error, "Prototype media file does not exist: #{@source_path}"}
    end
  end

  defp probe_source(source_path) do
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
        {:ok, build_metadata(Jason.decode!(json))}

      {output, status} ->
        {:error, "ffprobe exited with #{status}: #{String.trim(output)}"}
    end
  rescue
    exception ->
      {:error, Exception.message(exception)}
  end

  defp build_metadata(%{"streams" => streams, "format" => format}) do
    video = Enum.find(streams, &(&1["codec_type"] == "video"))
    duration = parse_float(format["duration"]) || stream_duration(video)
    width = video["width"]
    height = video["height"]

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

    source_bit_rate = parse_int(video["bit_rate"]) || parse_int(get_in(video, ["tags", "BPS"]))

    %{
      title: get_in(format, ["tags", "title"]) || Path.basename(@source_path),
      duration: duration,
      segment_duration: @segment_duration,
      segment_count: duration |> Kernel./(@segment_duration) |> Float.ceil() |> trunc(),
      video: %{
        codec: video["codec_name"],
        width: width,
        height: height,
        frame_rate: frame_rate(video["avg_frame_rate"] || video["r_frame_rate"]),
        bit_rate: source_bit_rate
      },
      qualities: qualities(width, height, source_bit_rate),
      audio_tracks: audio_tracks,
      subtitle_tracks: subtitle_tracks
    }
  end

  defp audio_track(stream, index) do
    language = get_in(stream, ["tags", "language"]) || "und"
    title = get_in(stream, ["tags", "title"])
    channels = stream["channels"] || 2

    %{
      id: "a#{index}",
      stream_index: stream["index"],
      codec: stream["codec_name"],
      language: language,
      label: track_label(language, title, "Audio #{index + 1}"),
      channels: channels,
      default?: get_in(stream, ["disposition", "default"]) == 1
    }
  end

  defp subtitle_track(stream, index) do
    language = get_in(stream, ["tags", "language"]) || "und"
    title = get_in(stream, ["tags", "title"])

    %{
      id: "s#{index}",
      stream_index: stream["index"],
      codec: stream["codec_name"],
      language: language,
      label: track_label(language, title, "Subtitle #{index + 1}"),
      default?: get_in(stream, ["disposition", "default"]) == 1,
      file_name: "s#{index}.vtt"
    }
  end

  defp supported_subtitle?(%{"codec_type" => "subtitle", "codec_name" => codec}) do
    codec in ["subrip", "webvtt", "ass", "ssa"]
  end

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

  defp qualities(source_width, source_height, source_bit_rate) do
    source_bit_rate = source_bit_rate || 2_500_000
    original_bitrate = (source_bit_rate * 2) |> max(3_500_000) |> min(6_500_000)

    [
      %{
        id: "original",
        label: "Original (#{source_height}p)",
        height: source_height,
        video_bitrate: original_bitrate
      },
      %{id: "720p", label: "720p", height: 720, video_bitrate: 2_800_000},
      %{id: "480p", label: "480p", height: 480, video_bitrate: 1_400_000},
      %{id: "360p", label: "360p", height: 360, video_bitrate: 800_000}
    ]
    |> Enum.map(fn quality -> Map.put(quality, :height, min(quality.height, source_height)) end)
    |> Enum.uniq_by(& &1.height)
    |> Enum.map(fn quality ->
      width = quality.height |> scaled_width(source_width, source_height)

      quality
      |> Map.put(:width, width)
      |> Map.put(:bandwidth, quality.video_bitrate + 192_000)
      |> Map.put(:average_bandwidth, quality.video_bitrate + 160_000)
    end)
  end

  defp scaled_width(height, source_width, source_height) do
    width = (source_width * height / source_height) |> round()

    if rem(width, 2) == 0 do
      width
    else
      width + 1
    end
  end

  defp describe_state(state) do
    %{
      id: state.id,
      title: state.metadata.title,
      duration: state.metadata.duration,
      segment_duration: state.metadata.segment_duration,
      segment_count: state.metadata.segment_count,
      video: state.metadata.video,
      qualities: state.metadata.qualities,
      audio_tracks: state.metadata.audio_tracks,
      subtitle_tracks: state.metadata.subtitle_tracks,
      master_url: "/play/hls/#{state.id}/master.m3u8"
    }
  end

  defp build_master_playlist(state) do
    subtitle_group = if state.metadata.subtitle_tracks == [], do: nil, else: "subs"

    %MultivariantPlaylist{
      version: 6,
      independent_segments: true,
      items:
        master_audio_tags(state) ++
          master_subtitle_tags(state) ++
          Enum.map(state.metadata.qualities, fn quality ->
            %Stream{
              bandwidth: quality.bandwidth,
              average_bandwidth: quality.average_bandwidth,
              codecs: "avc1.4d401f,mp4a.40.2",
              resolution: {quality.width, quality.height},
              frame_rate: state.metadata.video.frame_rate,
              audio: "audio",
              subtitles: subtitle_group,
              uri: "video/#{quality.id}/index.m3u8"
            }
          end)
    }
    |> ExM3U8.serialize()
  end

  defp master_audio_tags(state) do
    Enum.map(state.metadata.audio_tracks, fn track ->
      %Media{
        type: :audio,
        group_id: "audio",
        name: playlist_escape(track.label),
        language: playlist_escape(track.language),
        default?: track.default?,
        auto_select?: true,
        channels: "2",
        uri: "audio/#{track.id}/index.m3u8"
      }
    end)
  end

  defp master_subtitle_tags(state) do
    Enum.map(state.metadata.subtitle_tracks, fn track ->
      %Media{
        type: :subtitles,
        group_id: "subs",
        name: playlist_escape(track.label),
        language: playlist_escape(track.language),
        default?: track.default?,
        auto_select?: true,
        uri: "subtitles/#{track.id}/index.m3u8"
      }
    end)
  end

  defp build_media_playlist(state, _quality) do
    build_segment_playlist(state, fn index -> "seg_#{pad_segment(index)}.ts" end)
  end

  defp build_audio_playlist(state, _track) do
    build_segment_playlist(state, fn index -> "seg_#{pad_segment(index)}.ts" end)
  end

  defp build_segment_playlist(state, segment_uri_fun) do
    target_duration = @segment_duration |> Float.ceil() |> trunc()

    %MediaPlaylist{
      info: %MediaPlaylistInfo{
        version: 6,
        target_duration: target_duration,
        media_sequence: 0,
        playlist_type: :vod,
        independent_segments: true,
        end_list?: true
      },
      timeline:
        Enum.flat_map(0..(state.metadata.segment_count - 1), fn index ->
          segment = %Segment{
            duration: segment_duration(state, index),
            uri: segment_uri_fun.(index)
          }

          if index == 0 do
            [segment]
          else
            [%Discontinuity{}, segment]
          end
        end)
    }
    |> ExM3U8.serialize()
  end

  defp build_subtitle_playlist(state, track) do
    target_duration = state.metadata.duration |> Float.ceil() |> trunc()

    %MediaPlaylist{
      info: %MediaPlaylistInfo{
        version: 6,
        target_duration: target_duration,
        media_sequence: 0,
        playlist_type: :vod,
        end_list?: true
      },
      timeline: [
        %Segment{
          duration: state.metadata.duration,
          uri: track.file_name
        }
      ]
    }
    |> ExM3U8.serialize()
  end

  defp ensure_video_segment(state, quality, index) do
    output_path =
      Path.join([state.output_dir, "video", quality.id, "seg_#{pad_segment(index)}.ts"])

    if cached?(output_path) do
      {:ok, output_path, false}
    else
      FfmpegTranscoder.transcode_video_segment(%{
        source_path: state.source_path,
        output_path: output_path,
        start_time: index * @segment_duration,
        duration: segment_duration(state, index),
        segment_duration: @segment_duration,
        width: quality.width,
        height: quality.height,
        video_bitrate: quality.video_bitrate
      })
      |> normalize_transcoder_result()
    end
  end

  defp ensure_audio_segment(state, track, index) do
    output_path = Path.join([state.output_dir, "audio", track.id, "seg_#{pad_segment(index)}.ts"])

    if cached?(output_path) do
      {:ok, output_path, false}
    else
      FfmpegTranscoder.transcode_audio_segment(%{
        source_path: state.source_path,
        output_path: output_path,
        start_time: index * @segment_duration,
        duration: segment_duration(state, index),
        stream_index: track.stream_index
      })
      |> normalize_transcoder_result()
    end
  end

  defp ensure_subtitle_file(state, track) do
    output_path = Path.join([state.output_dir, "subtitles", track.id, track.file_name])

    if cached?(output_path) do
      {:ok, output_path, false}
    else
      FfmpegTranscoder.transcode_subtitle_file(%{
        source_path: state.source_path,
        output_path: output_path,
        stream_index: track.stream_index
      })
      |> normalize_transcoder_result()
    end
  end

  defp normalize_transcoder_result({:ok, path}), do: {:ok, path, true}
  defp normalize_transcoder_result({:error, reason}), do: {:error, reason}

  defp apply_segment_result({:ok, path, generated?}, state) do
    state =
      if generated? do
        %{state | generated_segments: state.generated_segments + 1, last_error: nil}
      else
        state
      end

    {{:ok, path}, state}
  end

  defp apply_segment_result({:error, reason}, state) do
    Logger.warning("HLS segment generation failed: #{inspect(reason)}")
    {{:error, reason}, %{state | last_error: inspect(reason)}}
  end

  defp apply_segment_result(:error, state), do: {{:error, :not_found}, state}

  defp cached?(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > 0 -> true
      _other -> false
    end
  end

  defp find_quality(state, id) do
    case Enum.find(state.metadata.qualities, &(&1.id == id)) do
      nil -> :error
      quality -> {:ok, quality}
    end
  end

  defp find_audio_track(state, id) do
    case Enum.find(state.metadata.audio_tracks, &(&1.id == id)) do
      nil -> :error
      track -> {:ok, track}
    end
  end

  defp find_subtitle_track(state, id) do
    case Enum.find(state.metadata.subtitle_tracks, &(&1.id == id)) do
      nil -> :error
      track -> {:ok, track}
    end
  end

  defp parse_segment_name(segment_name) do
    case Regex.run(~r/^seg_(\d+)\.ts$/, segment_name) do
      [_segment_name, index] -> {:ok, String.to_integer(index)}
      _no_match -> {:error, :not_found}
    end
  end

  defp validate_segment_index(state, index) do
    if index >= 0 and index < state.metadata.segment_count do
      :ok
    else
      {:error, :not_found}
    end
  end

  defp validate_subtitle_file_name(track, file_name) do
    if file_name == track.file_name do
      :ok
    else
      {:error, :not_found}
    end
  end

  defp segment_duration(state, index) do
    remaining = state.metadata.duration - index * @segment_duration
    min(@segment_duration, max(remaining, 0.1))
  end

  defp build_status(state) do
    %{
      id: state.id,
      title: state.metadata.title,
      output_dir: state.output_dir,
      started_at: state.started_at,
      duration: state.metadata.duration,
      segment_count: state.metadata.segment_count,
      generated_segments: state.generated_segments,
      cached_files: cached_files(state.output_dir),
      last_error: state.last_error
    }
  end

  defp cached_files(output_dir) do
    case File.exists?(output_dir) do
      true ->
        output_dir
        |> Path.join("**/*")
        |> Path.wildcard()
        |> Enum.count(&File.regular?/1)

      false ->
        0
    end
  end

  defp touch(state), do: %{state | last_accessed_at: System.monotonic_time(:millisecond)}

  defp cleanup_stale_sessions do
    File.mkdir_p!(@cache_root)
    now = System.os_time(:second)

    @cache_root
    |> File.ls!()
    |> Enum.map(&Path.join(@cache_root, &1))
    |> Enum.each(fn path ->
      case File.stat(path, time: :posix) do
        {:ok, %{type: :directory, mtime: mtime}} when now - mtime > @stale_session_age_seconds ->
          File.rm_rf(path)

        _other ->
          :ok
      end
    end)
  rescue
    exception ->
      Logger.debug("Could not clean stale HLS sessions: #{Exception.message(exception)}")
      :ok
  end

  defp new_session_id do
    12
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp track_label(language, title, fallback) do
    language_name = language_name(language)

    case title do
      nil -> "#{language_name} — #{fallback}"
      "" -> "#{language_name} — #{fallback}"
      title -> "#{language_name} — #{title}"
    end
  end

  defp language_name("eng"), do: "English"
  defp language_name("en"), do: "English"
  defp language_name("fre"), do: "French"
  defp language_name("fra"), do: "French"
  defp language_name("fr"), do: "French"
  defp language_name("und"), do: "Unknown"
  defp language_name(language), do: String.upcase(language)

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

  defp pad_segment(index), do: index |> Integer.to_string() |> String.pad_leading(5, "0")

  defp playlist_escape(value) do
    value
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end
end
