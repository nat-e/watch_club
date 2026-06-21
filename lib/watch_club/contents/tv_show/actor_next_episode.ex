defmodule WatchClub.Contents.TvShow.ActorNextEpisode do
  @moduledoc """
  Manual relationship resolving the episode the current user should play next:
  the first episode (by season/episode order) they have not completed, or the
  first episode of the show when they have completed all of them.

  Implements the AshPostgres callbacks so it can also be traversed inside
  expressions (e.g. the `has_media?` calculation), where it resolves to the same
  episode via a correlated `ORDER BY … LIMIT 1` lateral join.
  """
  use Ash.Resource.ManualRelationship
  use AshPostgres.ManualRelationship

  require Ash.Query
  import Ecto.Query

  alias WatchClub.Contents.TvShowEpisode

  @impl true
  def load(shows, _opts, %{actor: actor, authorize?: authorize?}) do
    episodes_by_show =
      TvShowEpisode
      |> Ash.Query.filter(tv_show_id in ^Enum.map(shows, & &1.id))
      |> Ash.Query.load(:actor_progress_status)
      |> Ash.read!(actor: actor, authorize?: authorize?)
      |> Enum.group_by(& &1.tv_show_id)

    {:ok,
     Map.new(shows, fn show ->
       episodes = Map.get(episodes_by_show, show.id, [])

       next =
         Enum.find(episodes, &(&1.actor_progress_status != :completed)) || List.first(episodes)

       {show.id, next}
     end)}
  end

  @impl true
  def ash_postgres_join(query, _opts, current_binding, as_binding, :inner, destination_query) do
    {:ok,
     from(row in query,
       inner_lateral_join: episode in subquery(next_episode(destination_query, current_binding)),
       as: ^as_binding,
       on: true
     )}
  end

  def ash_postgres_join(query, _opts, current_binding, as_binding, :left, destination_query) do
    {:ok,
     from(row in query,
       left_lateral_join: episode in subquery(next_episode(destination_query, current_binding)),
       as: ^as_binding,
       on: true
     )}
  end

  @impl true
  def ash_postgres_subquery(_opts, current_binding, _as_binding, destination_query) do
    {:ok, next_episode(destination_query, current_binding)}
  end

  # The single next-or-first episode for the parent show, ordered so that
  # completed episodes sort last (falling back to the first episode).
  defp next_episode(destination_query, parent_binding) do
    actor_id =
      case destination_query.__ash_bindings__.context[:private][:actor] do
        %{id: id} -> id
        _ -> nil
      end

    from(episode in destination_query,
      where: episode.tv_show_id == parent_as(^parent_binding).id,
      limit: 1
    )
    |> order_by_next(actor_id)
  end

  defp order_by_next(query, nil) do
    from(episode in query, order_by: [asc: episode.season_number, asc: episode.episode_number])
  end

  defp order_by_next(query, actor_id) do
    from(episode in query,
      order_by: [
        asc:
          fragment(
            "EXISTS (SELECT 1 FROM watch_progresses wp WHERE wp.tv_show_episode_id = ? AND wp.user_id = ? AND (wp.position_seconds IS NULL OR wp.duration_seconds IS NULL OR wp.position_seconds / wp.duration_seconds >= 0.9))",
            episode.id,
            ^actor_id
          ),
        asc: episode.season_number,
        asc: episode.episode_number
      ]
    )
  end
end
