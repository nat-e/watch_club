defmodule WatchClub.Playbacks.Workers.EndAbandonedSessions do
  @moduledoc """
  Ends the Playback Sessions without a Screen for two minutes and deletes the segment cache of
  ended Playbacks. Runs every minute (see `config/config.exs`). A failed run isn't retried: the
  next scheduled run takes its place.
  """
  use Oban.Worker, queue: :playback_cache_maintenance, max_attempts: 1

  alias WatchClub.Playbacks
  alias WatchClub.SystemActor

  @impl Oban.Worker
  def perform(_job) do
    Playbacks.end_abandoned_sessions!(actor: SystemActor.actor())
  end
end
