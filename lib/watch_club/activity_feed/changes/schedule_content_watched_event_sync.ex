defmodule WatchClub.ActivityFeed.Changes.ScheduleContentWatchedEventSync do
  @moduledoc """
  Schedules the SyncContentWatchedFeedEvent Oban Worker to run a minute after a WatchProgress is
  recorded, so a playing user's progress updates the Activity Feed once per minute
  """
  use Ash.Resource.Change

  alias WatchClub.ActivityFeed.Workers.SyncContentWatchedFeedEvent
  alias WatchClub.History.WatchProgress

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, watch_progress ->
      %WatchProgress{content: content} = Ash.load!(watch_progress, [:content], authorize?: false)

      OpentelemetryOban.insert!(
        SyncContentWatchedFeedEvent.new_delayed_job(watch_progress.user_id, content.id)
      )

      {:ok, watch_progress}
    end)
  end
end
