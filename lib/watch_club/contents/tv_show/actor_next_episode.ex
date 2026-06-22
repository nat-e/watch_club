defmodule WatchClub.Contents.TvShow.ActorNextEpisode do
  @moduledoc """
  Resolves the episode the current user should resume on next play.

  The anchor is the episode the user watched most recently (ties — e.g. a whole
  season marked at once — broken by airing order). From there:

    * nothing watched yet      → the first episode
    * anchor still in progress → the anchor itself (resume it)
    * anchor completed         → the next episode in airing order, wrapping
                                 back to the first once the finale is done
  """
  use Ash.Resource.ManualRelationship

  require Ash.Query

  alias WatchClub.Contents.TvShowEpisode

  @impl true
  def load(shows, _opts, %{actor: actor, authorize?: authorize?}) do
    episodes_by_show =
      TvShowEpisode
      |> Ash.Query.filter(tv_show_id in ^Enum.map(shows, & &1.id))
      |> Ash.Query.load([:actor_progress_status, :actor_last_watched_at])
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

      %{actor_progress_status: :completed} = anchor ->
        successor =
          Enum.find(episodes, fn episode ->
            {episode.season_number, episode.episode_number} >
              {anchor.season_number, anchor.episode_number}
          end)

        successor || List.first(episodes)

      anchor ->
        anchor
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
