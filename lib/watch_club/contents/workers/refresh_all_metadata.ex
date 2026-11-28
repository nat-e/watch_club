defmodule WatchClub.Contents.Workers.RefreshAllMetadata do
  @moduledoc """
  Refreshes the metadata of every Content, such as for a new User Locale. A migration schedules
  it when stored metadata needs fetching again:

      execute \"""
      INSERT INTO oban_jobs (worker, queue, max_attempts)
      SELECT 'WatchClub.Contents.Workers.RefreshAllMetadata', 'metadata_refreshes', 3
      WHERE EXISTS (SELECT 1 FROM contents)
      \"""

  A retry skips the Content refreshed since the job was scheduled.
  """
  use Oban.Worker, queue: :metadata_refreshes, max_attempts: 3

  alias WatchClub.Contents
  alias WatchClub.SystemActor

  @impl Oban.Worker
  def perform(%Oban.Job{inserted_at: inserted_at}) do
    Contents.refresh_all_metadata!(inserted_at, actor: SystemActor.actor())
  end
end
