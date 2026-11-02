defmodule WatchClub.Playbacks.Playback.SegmentCache do
  @moduledoc false

  require Ash.Query

  alias WatchClub.Playbacks.Playback
  alias WatchClub.SystemActor

  @cache_dir_name "watch_club_hls"

  defp root do
    Application.get_env(
      :watch_club,
      :segment_cache_root,
      Path.join(System.tmp_dir!(), @cache_dir_name)
    )
  end

  def playback_dir(playback_id), do: Path.join(root(), playback_id)

  @doc """
  Deletes the cache folder of every Playback that isn't current. Raises when
  the Playbacks can't be read or a folder can't be deleted.
  """
  def prune_stale! do
    File.mkdir_p!(root())
    # A folder is only created once its Playback is saved, so listing the folders
    # before reading the Playbacks keeps the folder of a Playback that starts in
    # between.
    cached_ids = File.ls!(root())
    current_ids = current_playback_ids()

    for playback_id <- cached_ids, playback_id not in current_ids do
      File.rm_rf!(playback_dir(playback_id))
    end

    :ok
  end

  defp current_playback_ids do
    Playback
    |> Ash.Query.filter(is_nil(ended_at))
    |> Ash.read!(actor: SystemActor.actor())
    |> MapSet.new(& &1.id)
  end
end
