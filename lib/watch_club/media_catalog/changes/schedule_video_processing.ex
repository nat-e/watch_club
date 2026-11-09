defmodule WatchClub.MediaCatalog.Changes.ScheduleVideoProcessing do
  @moduledoc """
  After a Video upsert commits, enqueues the jobs that read its file: the
  scrubbing thumbnails (`GenerateTrickplay`) and the Markers (`DetectMarkers`).
  The workers' `unique` config coalesces the burst of jobs a library re-scan
  produces.
  """

  use Ash.Resource.Change

  alias WatchClub.MediaCatalog.Workers.{DetectMarkers, GenerateTrickplay}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, media} <- result do
        OpentelemetryOban.insert!(GenerateTrickplay.new_job(media.id))
        OpentelemetryOban.insert!(DetectMarkers.new_job(media.id))
        {:ok, media}
      end
    end)
  end
end
