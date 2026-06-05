defmodule WatchClub.Contents.Changes.DeleteViewerProgress do
  @moduledoc """
  Deletes the current user's WatchProgress for the Content being updated
  (Movie, Book or TV Show Episode), if any.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias WatchClub.Contents.{Book, Movie, TvShowEpisode}
  alias WatchClub.History.WatchProgress

  @impl true
  def change(changeset, _opts, context) do
    actor = context.actor

    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      record
      |> viewer_progress_query(actor)
      |> Ash.bulk_destroy!(:destroy, %{}, scope: context)

      {:ok, record}
    end)
  end

  defp viewer_progress_query(%Movie{id: id}, actor),
    do: Ash.Query.filter(WatchProgress, movie_id == ^id and user_id == ^actor.id)

  defp viewer_progress_query(%Book{id: id}, actor),
    do: Ash.Query.filter(WatchProgress, book_id == ^id and user_id == ^actor.id)

  defp viewer_progress_query(%TvShowEpisode{id: id}, actor),
    do: Ash.Query.filter(WatchProgress, tv_show_episode_id == ^id and user_id == ^actor.id)
end
