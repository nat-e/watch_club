defmodule WatchClub.Markers.Changes.ScheduleDetection do
  @moduledoc """
  After a Video upsert commits, enqueues the `DetectMarkers` job that finds its Markers,
  with the other episodes of its season when it is a TV Show Episode.
  """

  use Ash.Resource.Change

  alias WatchClub.Markers.Workers.DetectMarkers

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, media} <- result do
        %{video: video} = Ash.load!(media, [video: :tv_show_episode], scope: context)
        OpentelemetryOban.insert!(DetectMarkers.new_job(video))
        {:ok, media}
      end
    end)
  end
end
