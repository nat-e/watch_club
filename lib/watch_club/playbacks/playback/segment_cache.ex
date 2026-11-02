defmodule WatchClub.Playbacks.Playback.SegmentCache do
  @moduledoc false

  require Ash.Query
  require Logger

  alias WatchClub.Playbacks.Playback
  alias WatchClub.SystemActor

  @cache_dir_name "watch_club_hls"

  def root do
    Application.get_env(
      :watch_club,
      :segment_cache_root,
      Path.join(System.tmp_dir!(), @cache_dir_name)
    )
  end

  def playback_dir(playback_id), do: Path.join(root(), playback_id)

  def prune_stale do
    File.mkdir_p!(root())
    live_ids = live_playback_ids()

    root()
    |> File.ls!()
    |> Enum.each(fn entry ->
      unless MapSet.member?(live_ids, entry) do
        File.rm_rf(Path.join(root(), entry))
      end
    end)
  rescue
    exception ->
      Logger.debug(
        "Could not clean stale playback segment cache: #{Exception.message(exception)}"
      )

      :ok
  end

  defp live_playback_ids do
    Playback
    |> Ash.Query.filter(is_nil(ended_at))
    |> Ash.read(actor: SystemActor.actor())
    |> case do
      {:ok, playbacks} -> MapSet.new(playbacks, & &1.id)
      _other -> MapSet.new()
    end
  end
end
