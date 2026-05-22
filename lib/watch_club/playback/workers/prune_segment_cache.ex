defmodule WatchClub.Playback.Workers.PruneSegmentCache do
  use Oban.Worker, queue: :playback_cache_maintenance

  alias WatchClub.Playback.Stream.SegmentCache

  @impl Oban.Worker
  def perform(_job) do
    SegmentCache.prune_stale()
    :ok
  end
end
