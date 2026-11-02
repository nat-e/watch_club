defmodule WatchClub.Playbacks.Workers.PruneSegmentCache do
  use Oban.Worker, queue: :playback_cache_maintenance

  alias WatchClub.Playbacks
  alias WatchClub.Playbacks.Playback.SegmentCache
  alias WatchClub.SystemActor

  @impl Oban.Worker
  def perform(_job) do
    Playbacks.end_inactive_playbacks!(actor: SystemActor.actor())
    SegmentCache.prune_stale()
    :ok
  end
end
