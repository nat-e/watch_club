defmodule WatchClub.Playbacks.Workers.PruneSegmentCache do
  use Oban.Worker, queue: :playback_cache_maintenance

  alias WatchClub.Playbacks.Playback.SegmentCache

  @impl Oban.Worker
  def perform(_job) do
    SegmentCache.prune_stale()
    :ok
  end
end
