defmodule WatchClub.Contents.TvShow.ActorNextEpisode do
  @moduledoc """
  Resolves the episode the current user should watch on next play.

    * nothing watched yet                             → the first episode
    * most recently watched episode still in progress → the episode
    * most recently watched episode completed         → the next episode in airing order
    * everything watched.                             → the first episode
  """
  use Ash.Resource.ManualRelationship

  require Ash.Query

  alias WatchClub.Contents.TvShowEpisode

  @impl true
  def load(shows, _opts, %{actor: actor, authorize?: authorize?}) do
    episodes_by_show =
      TvShowEpisode
      |> Ash.Query.filter(tv_show_id in ^Enum.map(shows, & &1.id))
      |> Ash.Query.load([:rank, :actor_progress_status, :actor_last_watched_at])
      |> Ash.read!(actor: actor, authorize?: authorize?)
      |> Enum.group_by(& &1.tv_show_id)

    {:ok,
     Map.new(shows, fn show ->
       {show.id, next_episode(Map.get(episodes_by_show, show.id, []))}
     end)}
  end

  defp next_episode([]), do: nil

  defp next_episode(episodes) do
    episodes = Enum.sort_by(episodes, &{&1.season_number, &1.episode_number})

    case most_recently_watched(episodes) do
      nil ->
        List.first(episodes)

      %{actor_progress_status: :completed} = most_recently_watched ->
        successor = Enum.find(episodes, &(&1.rank > most_recently_watched.rank))
        successor || List.first(episodes)

      most_recently_watched ->
        most_recently_watched
    end
  end

  # Most recently watched episode, ties broken by airing order — episodes are
  # sorted ascending, so an equal timestamp keeps the later one. This is the
  # selection actor_last_watched_episode used to do in SQL.
  defp most_recently_watched(episodes) do
    episodes
    |> Enum.reject(&is_nil(&1.actor_last_watched_at))
    |> Enum.reduce(nil, fn episode, latest ->
      if latest && DateTime.after?(latest.actor_last_watched_at, episode.actor_last_watched_at),
        do: latest,
        else: episode
    end)
  end
end
