defmodule WatchClub.Contents.Changes.SetViewerProgressCompleted do
  @moduledoc """
  Upserts a completed WatchProgress for the current user for the Content being
  updated (Movie, Book or TV Show Episode).

  Marking watched resets position_seconds and clears last_media_id, so a content
  that was partway watched flips cleanly to completed.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents.{Book, Movie, TvShowEpisode}
  alias WatchClub.History

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      mark_completed(record, context)
      {:ok, record}
    end)
  end

  defp mark_completed(%Movie{id: id}, context),
    do:
      History.record_movie_progress!(
        %{movie_id: id, completed: true, position_seconds: 0, last_media_id: nil},
        scope: context
      )

  defp mark_completed(%Book{id: id}, context),
    do:
      History.record_book_progress!(
        %{book_id: id, completed: true, position_seconds: 0, last_media_id: nil}, scope: context)

  defp mark_completed(%TvShowEpisode{id: id}, context),
    do:
      History.record_episode_progress!(
        %{tv_show_episode_id: id, completed: true, position_seconds: 0, last_media_id: nil},
        scope: context
      )
end
