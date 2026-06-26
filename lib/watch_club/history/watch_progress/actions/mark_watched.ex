defmodule WatchClub.History.WatchProgress.Actions.MarkWatched do
  @moduledoc """
  Marks a Content watched for the acting user.
  Can be filtered by season_id and/or episode_id for TV Shows.

  This will return a single notification, even when multiple TV Shows
  episodes are marked.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias WatchClub.ActivityFeed.Workers.SyncContentWatchedFeedEvent
  alias WatchClub.Contents
  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.History.WatchProgress

  @impl true
  def run(input, _opts, context) do
    actor = context.actor

    with {:ok, content} <- Contents.get_or_create_content(input.arguments.content_identity, actor),
         notifications <-
           mark_watched!(
             content,
             Map.get(input.arguments, :season_number),
             Map.get(input.arguments, :episode_number),
             context
           ) do
      Oban.insert!(SyncContentWatchedFeedEvent.new_job(actor.id, content.id))
      {:ok, content, notifications}
    end
  end

  defp mark_watched!(%{type: :movie, id: id}, _season, _episode, context) do
    {_progress, notifications} =
      WatchProgress
      |> Ash.create!(
        %{movie_id: id},
        action: :mark_watched,
        scope: context,
        return_notifications?: true
      )

    notifications
  end

  defp mark_watched!(%{type: :book, id: id}, _season, _episode, context) do
    {_progress, notifications} =
      WatchProgress
      |> Ash.create!(
        %{book_id: id},
        action: :mark_watched,
        scope: context,
        return_notifications?: true
      )

    notifications
  end

  defp mark_watched!(%{type: :tv_show, id: tv_show_id}, season, episode, context) do
    inputs =
      tv_show_id
      |> episode_ids(season, episode, context)
      |> Enum.map(&%{tv_show_episode_id: &1})

    %Ash.BulkResult{notifications: notifications} =
      Ash.bulk_create!(inputs, WatchProgress, :mark_watched,
        scope: context,
        return_records?: false,
        return_notifications?: true
      )

    # We just return a single notification for one of the episode to avoid flooding the subscribers
    # This is fine since we reload data anyway
    Enum.take(notifications, 1)
  end

  # nil season/episode mean "all", so the filter is a no-op for that scope.
  defp episode_ids(tv_show_id, season, episode, context) do
    TvShowEpisode
    |> Ash.Query.filter(tv_show_id == ^tv_show_id)
    |> filter_by_season_number(season)
    |> filter_by_episode_number(episode)
    |> Ash.read!(scope: context)
    |> Enum.map(& &1.id)
  end

  defp filter_by_season_number(query, nil), do: query

  defp filter_by_season_number(query, season_number) do
    query |> Ash.Query.filter(season_number == ^season_number)
  end

  defp filter_by_episode_number(query, nil), do: query

  defp filter_by_episode_number(query, episode_number) do
    query |> Ash.Query.filter(episode_number == ^episode_number)
  end
end
