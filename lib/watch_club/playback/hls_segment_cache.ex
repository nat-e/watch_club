defmodule WatchClub.Playback.HlsSegmentCache do
  @moduledoc false

  require Logger

  @default_stale_session_age_seconds 6 * 60 * 60

  def root do
    :watch_club
    |> Application.get_env(WatchClub.Playback, [])
    |> Keyword.get(:cache_root, Path.join(System.tmp_dir!(), "watch_club_hls"))
  end

  def session_dir(playback_session_id) do
    Path.join(root(), playback_session_id)
  end

  def stale_session_age_seconds do
    :watch_club
    |> Application.get_env(WatchClub.Playback, [])
    |> Keyword.get(:stale_session_age_seconds, @default_stale_session_age_seconds)
  end

  def cleanup_stale_sessions do
    File.mkdir_p!(root())
    now = System.os_time(:second)
    max_age_seconds = stale_session_age_seconds()

    root()
    |> File.ls!()
    |> Enum.map(&Path.join(root(), &1))
    |> Enum.each(fn path ->
      if session_running?(path) do
        :ok
      else
        case File.stat(path, time: :posix) do
          {:ok, %{type: :directory, mtime: mtime}} when now - mtime > max_age_seconds ->
            File.rm_rf(path)

          _other ->
            :ok
        end
      end
    end)
  rescue
    exception ->
      Logger.debug(
        "Could not clean stale playback session cache: #{Exception.message(exception)}"
      )

      :ok
  end

  defp session_running?(path) do
    path
    |> Path.basename()
    |> WatchClub.Playback.PlaybackSessionRegistry.session_running?()
  end
end
