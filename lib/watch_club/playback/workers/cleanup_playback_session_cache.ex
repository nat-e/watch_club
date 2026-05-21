defmodule WatchClub.Playback.Workers.CleanupPlaybackSessionCache do
  use Oban.Worker, queue: :playback_cache_maintenance

  alias WatchClub.Playback.HlsSegmentCache

  @impl Oban.Worker
  def perform(_job) do
    HlsSegmentCache.cleanup_stale_sessions()
    :ok
  end
end
