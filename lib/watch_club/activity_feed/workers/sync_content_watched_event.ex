defmodule WatchClub.ActivityFeed.Workers.SyncContentWatchedFeedEvent do
  @moduledoc """
  An Oban Worker that recomputes the derived ContentWatchedEvent for a (user, content) from
  the user's WatchProgress.

  It will delete the event if the Content is :not_started by the User, or update it otherwise.
  The jobs will be unique for user_id x content_id, so it is safe to be called multiple times when
  marking multiple episodes watched/unwatched at once, or on every player heartbeat.
  We chose to perform this action in an Oban Job since eventual consistency is good enough, and this
  allows the User facing actions to be faster, while keeping the complexity low.
  """

  use Oban.Worker,
    queue: :activity_feed_event_handlers,
    max_attempts: 3,
    unique: [
      fields: [:worker, :args],
      keys: [:user_id, :content_id],
      states: [:available, :scheduled],
      period: :infinity
    ]

  require Ash.Query

  alias WatchClub.{Accounts, Contents}
  alias WatchClub.ActivityFeed.Events.ContentWatchedEvent
  alias WatchClub.Contents.TvShow

  @doc """
  Builds a job that syncs a user/content now, and brings forward a delayed one for the same
  user/content. `replace` only copies a time the job sets, hence the explicit `scheduled_at`.
  """
  def new_job(user_id, content_id) do
    new(%{user_id: user_id, content_id: content_id},
      scheduled_at: DateTime.utc_now(),
      replace: [scheduled: [:scheduled_at]]
    )
  end

  @doc """
  Builds a job that syncs a user/content in a minute. The player records progress on every
  heartbeat, every few seconds: the unique job merges them into one sync per minute.
  """
  def new_delayed_job(user_id, content_id),
    do: new(%{user_id: user_id, content_id: content_id}, schedule_in: 60)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "content_id" => content_id}}) do
    actor = Accounts.get_user_by_id!(user_id, authorize?: false)

    content =
      Contents.get_content_by_id!(content_id,
        load: [
          :actor_progress_status,
          implementation: %{load: [tv_show: [episodes: [:actor_progress_status]]]},
          library_items: [:library]
        ],
        actor: actor
      )

    case content.actor_progress_status do
      :not_started ->
        # The content has been marked unwatched, destroy the event
        ContentWatchedEvent
        |> Ash.Query.filter(actor_id == ^actor.id and content_id == ^content_id)
        |> Ash.read_one!(actor: actor)
        |> case do
          nil -> nil
          # Scopes have no destroy policy: this is a system-derived projection
          event -> Ash.destroy!(event, actor: actor, authorize?: false)
        end

      status ->
        # The content has been watched or updated, upsert the event
        ContentWatchedEvent
        |> Ash.create!(
          %{
            content_id: content_id,
            completed: status == :completed,
            completed_episodes: completed_episodes(content.implementation),
            scopes: event_scopes(user_id, content.library_items)
          },
          action: :upsert,
          # System-derived projection: skip policies on the write (actor still set so relate_actor
          # assigns actor_id).
          actor: actor,
          authorize?: false
        )
    end

    :ok
  end

  # Every scope shares the group, see SetGroupKey
  defp event_scopes(user_id, library_items) do
    group = "watched:#{user_id}"

    club_scopes =
      library_items
      |> Enum.map(&%{scope_club_id: &1.library.club_id, group: group})
      |> Enum.uniq()

    [%{scope_user_id: user_id, group: group} | club_scopes]
  end

  defp completed_episodes(%TvShow{episodes: episodes}) do
    episodes
    |> Enum.filter(&(&1.actor_progress_status == :completed))
    |> Enum.map(&%{season_number: &1.season_number, episode_number: &1.episode_number})
  end

  defp completed_episodes(_movie_or_book), do: nil
end
