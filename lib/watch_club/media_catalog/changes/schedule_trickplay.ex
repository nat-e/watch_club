defmodule WatchClub.MediaCatalog.Changes.ScheduleTrickplay do
  @moduledoc """
  Enqueues a `GenerateTrickplay` job to build the Video's Scrubbing Thumbnails when its file is
  new or its File Fingerprint changed, or when they're missing. With `always?: true`, every time.

  The job is inserted in the action's transaction, so it runs once the Video is saved. The
  worker's `unique` config coalesces the jobs of one Video.
  """

  use Ash.Resource.Change

  alias WatchClub.Ffmpeg.Trickplay
  alias WatchClub.MediaCatalog.Workers.GenerateTrickplay

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, video ->
      if Keyword.get(opts, :always?, false) or
           Ash.Changeset.changing_attribute?(changeset, :file_fingerprint) or
           not Trickplay.generated?(video.id) do
        OpentelemetryOban.insert!(GenerateTrickplay.new_job(video.id))
      end

      {:ok, video}
    end)
  end
end
