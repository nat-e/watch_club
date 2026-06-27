defmodule WatchClub.ActivityFeed.Events.ContentWatchedEvent do
  @moduledoc """
  A :content_watched activity feed event: a User is watching / has watched a Content.

  There is exactly one ContentWatchedEvent per (actor, content). It is a derived projection of the
  User's WatchProgress for that Content, recomputed by `Actions.Sync` after every watch action:
  - it exists iff the User has at least one WatchProgress for the Content (partial or completed)
  - `completed` is true when the whole Content is completed (a Movie/Book that's completed, or a
    TV Show whose every episode is completed)
  - `completed_episodes` lists the completed episodes (empty for Movies/Books and partial watches)

  It fans out to one personal scope (the User) plus one scope per Club whose library holds the
  Content, all sharing this single event.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Accounts.User
  alias WatchClub.ActivityFeed.FeedEventScope
  alias WatchClub.Contents.Content

  postgres do
    table "activity_feed_content_watched_events"
    repo WatchClub.Repo

    identity_index_names unique_per_actor_content: "acwe_unique_per_actor_content_index"

    references do
      reference :actor, on_delete: :delete
      reference :content, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :upsert do
      primary? true
      upsert? true
      upsert_identity :unique_per_actor_content
      upsert_fields [:completed, :completed_episodes]

      accept [:actor_id, :content_id, :completed, :completed_episodes]
      argument :scopes, {:array, :map}, allow_nil?: false

      change relate_actor(:actor)
      # Reconcile the scope set on every sync so it converges to the current club fan-out
      change manage_relationship(:scopes, type: :direct_control)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    # Whether the entire Content has been completed
    attribute :completed, :boolean, allow_nil?: false, default: false

    # Completed episodes as [%{season_number: integer, episode_number: integer}] (TV shows only)
    attribute :completed_episodes, {:array, :map} do
      allow_nil? true

      constraints items: [
                    fields: [
                      season_number: [type: :integer, allow_nil?: false],
                      episode_number: [type: :integer, allow_nil?: false]
                    ]
                  ]
    end
  end

  relationships do
    belongs_to :actor, User, allow_nil?: false
    belongs_to :content, Content, allow_nil?: false
    has_many :scopes, FeedEventScope, destination_attribute: :content_watched_event_id
  end

  identities do
    identity :unique_per_actor_content, [:actor_id, :content_id]
  end
end
