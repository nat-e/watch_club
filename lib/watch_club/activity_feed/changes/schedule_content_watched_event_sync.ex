defmodule WatchClub.ActivityFeed.Changes.ScheduleContentWatchedEventSync do
  @moduledoc """
  Schedules the SyncContentWatchedFeedEvent Oban Worker to run
  """
  use Ash.Resource.Change

  alias WatchClub.ActivityFeed.Workers.SyncContentWatchedFeedEvent
  alias WatchClub.History.WatchProgress

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, watch_progress ->
      %WatchProgress{content: content} = Ash.load!(watch_progress, [:content], authorize?: false)
      Oban.insert!(SyncContentWatchedFeedEvent.new_job(watch_progress.user_id, content.id))
      {:ok, watch_progress}
    end)
  end
end
