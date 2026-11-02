defmodule WatchClub.Playbacks.Workers.PruneSegmentCache do
  @moduledoc """
  Ends the Playbacks whose Player is no longer active and deletes the segment
  cache of ended Playbacks. Runs every 15 minutes (see `config/config.exs`).
  """
  use Oban.Worker, queue: :playback_cache_maintenance

  alias WatchClub.Playbacks
  alias WatchClub.SystemActor

  @impl Oban.Worker
  def perform(_job) do
    Playbacks.end_inactive_playbacks!(actor: SystemActor.actor())
  end
end
