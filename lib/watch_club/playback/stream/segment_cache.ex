defmodule WatchClub.Playback.Stream.SegmentCache do
  @moduledoc false

  require Logger

  @cache_dir_name "watch_club_hls"
  @stale_age_seconds 6 * 60 * 60

  def root, do: Path.join(System.tmp_dir!(), @cache_dir_name)

  def stream_dir(stream_id), do: Path.join(root(), stream_id)

  def prune_stale do
    File.mkdir_p!(root())
    now = System.os_time(:second)
    live_ids = live_stream_ids()

    root()
    |> File.ls!()
    |> Enum.map(&Path.join(root(), &1))
    |> Enum.each(fn path ->
      if MapSet.member?(live_ids, Path.basename(path)) do
        :ok
      else
        case File.stat(path, time: :posix) do
          {:ok, %{type: :directory, mtime: mtime}} when now - mtime > @stale_age_seconds ->
            File.rm_rf(path)

          _other ->
            :ok
        end
      end
    end)
  rescue
    exception ->
      Logger.debug(
        "Could not clean stale playback stream cache: #{Exception.message(exception)}"
      )

      :ok
  end

  defp live_stream_ids do
    case Ash.read(WatchClub.Playback.Stream, actor: WatchClub.SystemActor.actor()) do
      {:ok, streams} -> MapSet.new(streams, & &1.id)
      _other -> MapSet.new()
    end
  end
end
