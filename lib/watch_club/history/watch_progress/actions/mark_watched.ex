defmodule WatchClub.History.WatchProgress.Actions.MarkWatched do
  @moduledoc """
  Marks a Content watched for the acting user.
  Can be filtered by season_id and/or episode_id for TV Shows
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias WatchClub.Contents
  alias WatchClub.Contents.Notifiers.ContentChangedNotifier
  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.History
  alias WatchClub.History.WatchProgress

  @impl true
  def run(input, _opts, context) do
    actor = context.actor

    with {:ok, content} <- Contents.get_or_create_content(input.arguments.content_identity, actor) do
      mark_watched(
        content,
        Map.get(input.arguments, :season_number),
        Map.get(input.arguments, :episode_number),
        context
      )

      notification =
        ContentChangedNotifier.create_notification(
          input.resource,
          input.action,
          content,
          [actor.id],
          actor
        )

      {:ok, content, [notification]}
    end
  end

  defp mark_watched(%{type: :movie, id: id}, _season, _episode, context) do
    History.record_movie_progress!(
      %{movie_id: id, last_media_id: nil},
      scope: context
    )
  end

  defp mark_watched(%{type: :book, id: id}, _season, _episode, context) do
    History.record_book_progress!(
      %{book_id: id, last_media_id: nil},
      scope: context
    )
  end

  defp mark_watched(%{type: :tv_show, id: tv_show_id}, season, episode, context) do
    inputs =
      tv_show_id
      |> episode_ids(season, episode, context)
      |> Enum.map(fn episode_id ->
        %{
          tv_show_episode_id: episode_id,
          last_media_id: nil
        }
      end)

    Ash.bulk_create!(inputs, WatchProgress, :record_episode_progress,
      scope: context,
      return_records?: false
    )
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
