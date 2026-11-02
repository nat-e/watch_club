defmodule WatchClub.Playbacks.Workers.PruneSegmentCache do
  use Oban.Worker, queue: :playback_cache_maintenance

  alias WatchClub.Playbacks
  alias WatchClub.SystemActor

  @impl Oban.Worker
  def perform(_job) do
    Playbacks.end_quiet_playbacks!(actor: SystemActor.actor())
  end
end
