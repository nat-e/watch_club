defmodule WatchClub.ActivityFeed.Changes.ScheduleContentWatchedEventSync do
  @moduledoc """
  Schedules the SyncContentWatchedFeedEvent Oban Worker to run
  """
  use Ash.Resource.Change

  alias WatchClub.ActivityFeed.Workers.SyncContentWatchedFeedEvent

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, watch_progress} <- result do
        %{content: content} = Ash.load!(watch_progress, [:content], authorize?: false)
        Oban.insert!(SyncContentWatchedFeedEvent.new_job(watch_progress.user_id, content.id))
        {:ok, watch_progress}
      end
    end)
  end
end
