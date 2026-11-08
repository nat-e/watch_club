defmodule WatchClub.MediaCatalog.Changes.ScheduleTrickplay do
  @moduledoc """
  After a Video upsert commits, enqueues a `GenerateTrickplay` job to build the
  Video's scrubbing thumbnails. The worker's `unique` config coalesces the burst
  of jobs a library re-scan produces.
  """

  use Ash.Resource.Change

  alias WatchClub.MediaCatalog.Workers.GenerateTrickplay

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, media} <- result do
        OpentelemetryOban.insert!(GenerateTrickplay.new_job(media.id))
        {:ok, media}
      end
    end)
  end
end
