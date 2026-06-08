defmodule WatchClub.History.WatchProgress.Actions.MarkNotWatched do
  @moduledoc """
  Marks a Content not watched for the acting user by deleting their
  WatchProgress for it.
  Can be filtered by season_id and/or episode_id for TV Shows
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias WatchClub.Contents
  alias WatchClub.History.WatchProgress

  @impl true
  def run(input, _opts, context) do
    actor = context.actor

    with {:ok, content} <- Contents.get_or_create_content(input.arguments.content_identity, actor) do
      content
      |> viewer_progress_query(
        Map.get(input.arguments, :season_number),
        Map.get(input.arguments, :episode_number),
        context.actor
      )
      |> Ash.bulk_destroy!(:destroy, %{},
        scope: context,
        strategy: :stream,
        return_records?: false
      )

      {:ok, content}
    end
  end

  defp viewer_progress_query(%{type: :movie, id: id}, _season, _episode, actor),
    do: Ash.Query.filter(WatchProgress, movie_id == ^id and user_id == ^actor.id)

  defp viewer_progress_query(%{type: :book, id: id}, _season, _episode, actor),
    do: Ash.Query.filter(WatchProgress, book_id == ^id and user_id == ^actor.id)

  # nil season/episode mean "all", so the filter is a no-op for that scope.
  defp viewer_progress_query(%{type: :tv_show, id: tv_show_id}, season, episode, actor) do
    WatchProgress
    |> Ash.Query.filter(tv_show_episode.tv_show_id == ^tv_show_id and user_id == ^actor.id)
    |> Ash.Query.filter(is_nil(^season) or tv_show_episode.season_number == ^season)
    |> Ash.Query.filter(is_nil(^episode) or tv_show_episode.episode_number == ^episode)
  end
end
