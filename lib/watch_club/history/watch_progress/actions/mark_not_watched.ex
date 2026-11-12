defmodule WatchClub.History.WatchProgress.Actions.MarkNotWatched do
  @moduledoc """
  Marks a Content not watched for the acting user by deleting their
  WatchProgress for it.
  Can be filtered by season_id and/or episode_id for TV Shows

  This will return a single notification, even when multiple TV Shows
  episodes are marked.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias WatchClub.Contents
  alias WatchClub.History.WatchProgress

  @impl true
  def run(input, _opts, context) do
    actor = context.actor

    with {:ok, content} <-
           Contents.get_or_refresh_content(
             input.arguments.content_identity,
             %{max_age: :infinity},
             scope: context
           ) do
      %Ash.BulkResult{notifications: notifications} =
        content
        |> viewer_progress_query(
          Map.get(input.arguments, :season_number),
          Map.get(input.arguments, :episode_number),
          actor
        )
        |> Ash.bulk_destroy!(:destroy, %{},
          scope: context,
          return_records?: false,
          return_notifications?: true
        )

      # We just return a single notification for one of the episode to avoid flooding the subscribers
      # This is fine since we reload data anyway
      {:ok, content, Enum.take(notifications, 1)}
    end
  end

  defp viewer_progress_query(%{type: :movie, id: id}, _season, _episode, actor),
    do: Ash.Query.filter(WatchProgress, movie_id == ^id and user_id == ^actor.id)

  defp viewer_progress_query(%{type: :sports_event, id: id}, _season, _episode, actor),
    do: Ash.Query.filter(WatchProgress, sports_event_id == ^id and user_id == ^actor.id)

  defp viewer_progress_query(%{type: :book, id: id}, _season, _episode, actor),
    do: Ash.Query.filter(WatchProgress, book_id == ^id and user_id == ^actor.id)

  # nil season/episode mean "all", so the filter is a no-op for that scope.
  defp viewer_progress_query(%{type: :tv_show, id: tv_show_id}, season, episode, actor) do
    WatchProgress
    |> Ash.Query.filter(tv_show_episode.tv_show_id == ^tv_show_id and user_id == ^actor.id)
    |> filter_by_season_number(season)
    |> filter_by_episode_number(episode)
  end

  defp filter_by_season_number(query, nil), do: query

  defp filter_by_season_number(query, season_number) do
    query |> Ash.Query.filter(tv_show_episode.season_number == ^season_number)
  end

  defp filter_by_episode_number(query, nil), do: query

  defp filter_by_episode_number(query, episode_number) do
    query |> Ash.Query.filter(tv_show_episode.episode_number == ^episode_number)
  end
end
