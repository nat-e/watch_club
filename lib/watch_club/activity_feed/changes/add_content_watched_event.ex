defmodule WatchClub.ActivityFeed.Changes.AddContentWatchedEvent do
  @moduledoc """
  Adds a Feed Event once the recorded Watch Progress is completed. The event's Feed Entry holds it
  only once, so the heartbeats that follow change nothing.
  """
  use Ash.Resource.Change

  alias WatchClub.ActivityFeed

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, watch_progress ->
      if Ash.load!(watch_progress, :completed, scope: context).completed do
        %{content: content} = Ash.load!(watch_progress, :content, scope: context)

        ActivityFeed.add_content_watched_event!(
          content.id,
          watch_progress.tv_show_episode_id,
          scope: context
        )
      end

      {:ok, watch_progress}
    end)
  end
end
