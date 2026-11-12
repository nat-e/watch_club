defmodule WatchClub.ActivityFeed.Events.ContentWatchedEvent do
  @moduledoc """
  A :content_watched Feed Event: a User finished a Movie, TV Show Episode or Sports Event by
  playing past 90% of it. Marking it as watched doesn't add one.

  A Feed Entry holds each Movie, TV Show Episode or Sports Event once: adding it again changes
  nothing. Every User sees the event. Its group_key identifies its Feed Entry.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Accounts.User
  alias WatchClub.ActivityFeed.Changes.SetGroupKey
  alias WatchClub.Contents.{Content, TvShowEpisode}

  postgres do
    table "activity_feed_content_watched_events"
    repo WatchClub.Repo

    custom_indexes do
      index [:group_key]
    end

    identity_index_names once_per_feed_entry: "acwe_once_per_feed_entry_index"

    references do
      # The once_per_feed_entry index starts with actor_id
      reference :actor, on_delete: :delete
      reference :content, on_delete: :delete, index?: true
      reference :tv_show_episode, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [:read]

    create :add do
      primary? true
      accept [:content_id, :tv_show_episode_id]

      upsert? true
      upsert_identity :once_per_feed_entry
      # Already in its Feed Entry: keep the event as it is
      upsert_condition expr(false)
      return_skipped_upsert? true

      change relate_actor(:actor)
      change SetGroupKey
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub
    prefix "feed"

    publish_all :create, ["global"],
      filter: &(!Ash.Resource.get_metadata(&1.data, :upsert_skipped))
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :group_key, :string, allow_nil?: false
    create_timestamp :created_at
  end

  relationships do
    belongs_to :actor, User, allow_nil?: false
    # The TV Show for a TV Show Episode
    belongs_to :content, Content, allow_nil?: false
    # Nil for a Movie or a Sports Event
    belongs_to :tv_show_episode, TvShowEpisode
  end

  identities do
    identity :once_per_feed_entry, [:actor_id, :content_id, :tv_show_episode_id, :group_key] do
      nils_distinct? false
    end
  end
end
