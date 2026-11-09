defmodule WatchClub.Markers.Changes.ScheduleDetection do
  @moduledoc """
  After a Video upsert commits, enqueues a `DetectMarkers` job to find its
  Markers. The worker's `unique` config coalesces the burst of jobs a library
  re-scan produces.
  """

  use Ash.Resource.Change

  alias WatchClub.Markers.Workers.DetectMarkers

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, media} <- result do
        OpentelemetryOban.insert!(DetectMarkers.new_job(media.id))
        {:ok, media}
      end
    end)
  end
end
