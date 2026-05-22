defmodule WatchClub.Playback.PlaybackSessionManager do
  @moduledoc """
  Public API and runtime process for one active Playback Session.

  The manager owns the temporary on-disk HLS segment cache for the Playback
  Session, keeps derived playlist metadata in memory, and starts supervised
  transcode tasks for segment cache misses. Web callers (controller, LiveView)
  go through the client API here; they do not talk to the GenServer pid
  directly.
  """

  use GenServer, restart: :transient, shutdown: 30_000

  alias WatchClub.Media.MediaProbe

  alias WatchClub.Playback.{
    FfmpegTranscoder,
    HlsPlaylistGenerator,
    HlsSegmentCache,
    PlaybackSessionRegistry,
    PlaybackSessionSupervisor,
    VideoQualityLadder
  }

  require Logger

  @segment_duration 6.0
  @call_timeout_ms 180_000

  defmodule Metadata do
    @moduledoc false
    @enforce_keys [
      :title,
      :duration,
      :video,
      :audio_tracks,
      :subtitle_tracks,
      :segment_duration,
      :segment_count,
      :qualities
    ]
    defstruct [
      :title,
      :duration,
      :video,
      :audio_tracks,
      :subtitle_tracks,
      :segment_duration,
      :segment_count,
      :qualities
    ]

    @type t :: %__MODULE__{
            title: String.t(),
            duration: float(),
            video: WatchClub.Media.MediaProbe.Video.t(),
            audio_tracks: [WatchClub.Media.MediaProbe.AudioTrack.t()],
            subtitle_tracks: [WatchClub.Media.MediaProbe.SubtitleTrack.t()],
            segment_duration: float(),
            segment_count: integer(),
            qualities: [WatchClub.Playback.VideoQualityLadder.Quality.t()]
          }
  end

  defmodule State do
    @moduledoc false
    @enforce_keys [
      :id,
      :user_id,
      :actor,
      :playback_session,
      :source_path,
      :output_dir,
      :metadata
    ]
    defstruct [
      :id,
      :user_id,
      :actor,
      :playback_session,
      :source_path,
      :output_dir,
      :metadata,
      :last_error,
      generated_segments: 0,
      pending_transcodes: %{}
    ]

    @type pending_transcode :: %{from: GenServer.from(), task: Task.t()}

    @type t :: %__MODULE__{
            id: String.t(),
            user_id: String.t(),
            actor: WatchClub.Accounts.User.t(),
            playback_session: WatchClub.Playback.PlaybackSession.t(),
            source_path: String.t(),
            output_dir: String.t(),
            metadata: WatchClub.Playback.PlaybackSessionManager.Metadata.t(),
            last_error: String.t() | nil,
            generated_segments: non_neg_integer(),
            pending_transcodes: %{reference() => pending_transcode()}
          }
  end

  def start_link(%{id: id, user_id: user_id} = opts) do
    GenServer.start_link(__MODULE__, opts, name: PlaybackSessionRegistry.via(user_id, id))
  end

  def start_session(actor, media_id) do
    with {:ok, playback_session} <-
           WatchClub.Playback.start_playback_session(media_id, actor: actor),
         {:ok, pid} <- start_or_reuse_process(actor, playback_session.id) do
      {:ok, GenServer.call(pid, :describe, @call_timeout_ms)}
    end
  end

  defp start_or_reuse_process(actor, playback_session_id) do
    case PlaybackSessionSupervisor.start_child(actor, playback_session_id) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  def describe(user_id, session_id) do
    with {:ok, pid} <- fetch(user_id, session_id) do
      {:ok, GenServer.call(pid, :describe, @call_timeout_ms)}
    end
  end

  def master_playlist(user_id, session_id) do
    call_session(user_id, session_id, :master_playlist)
  end

  def video_playlist(user_id, session_id, variant_id) do
    call_session(user_id, session_id, {:video_playlist, variant_id})
  end

  def audio_playlist(user_id, session_id, track_id) do
    call_session(user_id, session_id, {:audio_playlist, track_id})
  end

  def subtitle_playlist(user_id, session_id, track_id) do
    call_session(user_id, session_id, {:subtitle_playlist, track_id})
  end

  def video_segment(user_id, session_id, variant_id, segment_name) do
    call_session(user_id, session_id, {:video_segment, variant_id, segment_name})
  end

  def audio_segment(user_id, session_id, track_id, segment_name) do
    call_session(user_id, session_id, {:audio_segment, track_id, segment_name})
  end

  def subtitle_file(user_id, session_id, track_id, file_name) do
    call_session(user_id, session_id, {:subtitle_file, track_id, file_name})
  end

  def status(user_id, session_id) do
    call_session(user_id, session_id, :status)
  end

  def heartbeat(user_id, session_id) do
    call_session(user_id, session_id, :heartbeat)
  end

  def stop(user_id, session_id) do
    with {:ok, pid} <- fetch(user_id, session_id) do
      GenServer.stop(pid, :normal)
      :ok
    end
  end

  @impl true
  def init(%{id: id, user_id: user_id, actor: actor}) do
    File.mkdir_p!(HlsSegmentCache.root())

    with {:ok, playback_session} <-
           WatchClub.Playback.get_playback_session_for_playback(id, actor: actor),
         %{media: %{path: source_path}} when is_binary(source_path) <- playback_session,
         :ok <- ensure_source_exists(source_path),
         {:ok, probe} <- MediaProbe.probe(source_path) do
      output_dir = HlsSegmentCache.session_dir(id)
      File.mkdir_p!(output_dir)

      qualities =
        VideoQualityLadder.build(probe.video.width, probe.video.height, probe.video.bit_rate)

      segment_count = probe.duration |> Kernel./(@segment_duration) |> Float.ceil() |> trunc()

      metadata = %Metadata{
        title: probe.title,
        duration: probe.duration,
        video: probe.video,
        audio_tracks: probe.audio_tracks,
        subtitle_tracks: probe.subtitle_tracks,
        segment_duration: @segment_duration,
        segment_count: segment_count,
        qualities: qualities
      }

      {:ok,
       %State{
         id: id,
         user_id: user_id,
         actor: actor,
         playback_session: playback_session,
         source_path: source_path,
         output_dir: output_dir,
         metadata: metadata
       }}
    else
      {:error, reason} -> {:stop, reason}
      %WatchClub.Playback.PlaybackSession{} -> {:stop, :media_not_found}
    end
  end

  @impl true
  def handle_call(:describe, _from, state) do
    {:reply, describe_state(state), state}
  end

  def handle_call(:master_playlist, _from, state) do
    {:reply, {:ok, HlsPlaylistGenerator.master(state.metadata, state.metadata.qualities)}, state}
  end

  def handle_call({:video_playlist, variant_id}, _from, state) do
    case find_quality(state, variant_id) do
      {:ok, _quality} -> {:reply, {:ok, build_segment_playlist(state)}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:audio_playlist, track_id}, _from, state) do
    case find_audio_track(state, track_id) do
      {:ok, _track} -> {:reply, {:ok, build_segment_playlist(state)}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:subtitle_playlist, track_id}, _from, state) do
    case find_subtitle_track(state, track_id) do
      {:ok, track} ->
        {:reply, {:ok, HlsPlaylistGenerator.subtitle(track, state.metadata.duration)}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:video_segment, variant_id, segment_name}, from, state) do
    with {:ok, quality} <- find_quality(state, variant_id),
         {:ok, index} <- parse_segment_name(segment_name),
         :ok <- validate_segment_index(state, index) do
      start_segment_transcode(from, state, fn -> ensure_video_segment(state, quality, index) end)
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:audio_segment, track_id, segment_name}, from, state) do
    with {:ok, track} <- find_audio_track(state, track_id),
         {:ok, index} <- parse_segment_name(segment_name),
         :ok <- validate_segment_index(state, index) do
      start_segment_transcode(from, state, fn -> ensure_audio_segment(state, track, index) end)
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:subtitle_file, track_id, file_name}, from, state) do
    with {:ok, track} <- find_subtitle_track(state, track_id),
         :ok <- ensure_expected_subtitle_file(track, file_name) do
      start_segment_transcode(from, state, fn -> ensure_subtitle_file(state, track) end)
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:status, _from, state) do
    {:reply, {:ok, build_status(state)}, state}
  end

  def handle_call(:heartbeat, _from, state) do
    case WatchClub.Playback.heartbeat_playback_session(state.playback_session, actor: state.actor) do
      {:ok, playback_session} ->
        {:reply, :ok, %{state | playback_session: playback_session}}

      {:error, reason} ->
        {:reply, {:error, reason}, %{state | last_error: inspect(reason)}}
    end
  end

  defp start_segment_transcode(from, state, transcode_fun) do
    task =
      Task.Supervisor.async_nolink(WatchClub.Playback.TranscodeTaskSupervisor, transcode_fun)

    pending_transcodes =
      Map.put(state.pending_transcodes, task.ref, %{from: from, task: task})

    {:noreply, %{state | pending_transcodes: pending_transcodes}}
  end

  @impl true
  def handle_info({ref, result}, state) when is_reference(ref) do
    case Map.pop(state.pending_transcodes, ref) do
      {%{from: from}, pending_transcodes} ->
        Process.demonitor(ref, [:flush])

        {reply, state} =
          apply_segment_result(result, %{state | pending_transcodes: pending_transcodes})

        GenServer.reply(from, reply)
        {:noreply, state}

      {nil, _pending_transcodes} ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Map.pop(state.pending_transcodes, ref) do
      {%{from: from}, pending_transcodes} ->
        Logger.warning("Playback segment generation task failed: #{inspect(reason)}")
        GenServer.reply(from, {:error, reason})

        {:noreply,
         %{state | pending_transcodes: pending_transcodes, last_error: inspect(reason)}}

      {nil, _pending_transcodes} ->
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.pending_transcodes, fn {_ref, %{task: task}} ->
      Task.shutdown(task, :brutal_kill)
    end)

    File.rm_rf(state.output_dir)
    :ok
  end

  defp call_session(user_id, session_id, message) do
    with {:ok, pid} <- fetch(user_id, session_id) do
      GenServer.call(pid, message, @call_timeout_ms)
    end
  end

  defp fetch(user_id, session_id), do: PlaybackSessionRegistry.lookup(user_id, session_id)

  defp ensure_source_exists(source_path) do
    if File.exists?(source_path) do
      :ok
    else
      {:error, "Playback media file does not exist: #{source_path}"}
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
      master_url: "/hls/#{state.id}/master.m3u8"
    }
  end

  defp build_segment_playlist(state) do
    HlsPlaylistGenerator.segments(
      state.metadata.duration,
      state.metadata.segment_count,
      state.metadata.segment_duration
    )
  end

  defp ensure_video_segment(state, quality, index) do
    output_path =
      Path.join([
        state.output_dir,
        "video",
        quality.id,
        "seg_#{HlsPlaylistGenerator.pad_segment(index)}.ts"
      ])

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
    output_path =
      Path.join([
        state.output_dir,
        "audio",
        track.id,
        "seg_#{HlsPlaylistGenerator.pad_segment(index)}.ts"
      ])

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

  defp cached?(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > 0 -> true
      _other -> false
    end
  end

  defp find_quality(state, id) do
    case Enum.find(state.metadata.qualities, &(&1.id == id)) do
      nil -> {:error, :not_found}
      quality -> {:ok, quality}
    end
  end

  defp find_audio_track(state, id) do
    case Enum.find(state.metadata.audio_tracks, &(&1.id == id)) do
      nil -> {:error, :not_found}
      track -> {:ok, track}
    end
  end

  defp find_subtitle_track(state, id) do
    case Enum.find(state.metadata.subtitle_tracks, &(&1.id == id)) do
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

  defp validate_segment_index(state, index) do
    if index >= 0 and index < state.metadata.segment_count do
      :ok
    else
      {:error, :not_found}
    end
  end

  defp ensure_expected_subtitle_file(track, file_name) do
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
end
