defmodule WatchClub.History.WatchProgress do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.History,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.{Movie, TvShowEpisode}
  alias WatchClub.MediaCatalog.Media

  postgres do
    table "watch_progresses"
    repo WatchClub.Repo

    identity_wheres_to_sql unique_movie_per_user: "movie_id IS NOT NULL",
                           unique_episode_per_user: "tv_show_episode_id IS NOT NULL"

    references do
      reference :user, on_delete: :delete, on_update: :update
      reference :movie, on_delete: :delete, on_update: :update
      reference :tv_show_episode, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy]

    create :record_movie_progress do
      upsert? true
      upsert_identity :unique_movie_per_user
      upsert_fields [:position_seconds, :last_media_id, :completed]

      accept [:movie_id, :last_media_id, :position_seconds, :completed]
      change relate_actor(:user)
    end

    create :record_episode_progress do
      upsert? true
      upsert_identity :unique_episode_per_user
      upsert_fields [:position_seconds, :last_media_id, :completed]

      accept [:tv_show_episode_id, :last_media_id, :position_seconds, :completed]
      change relate_actor(:user)
    end
  end

  policies do
    policy actor_absent() do
      description "WatchProgress actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    # The two ownership checks are not interchangeable: `relating_to_actor`
    # inspects the changeset ("is this write setting `user` to the actor?"), so
    # it only resolves on creates/updates. `relates_to_actor_via` filters on the
    # persisted row (`user_id == actor.id`), which is what reads and destroys need
    # — using `relating_to_actor` there forbids every read.
    policy action([:record_movie_progress, :record_episode_progress]) do
      description "A User records only their own Watch Progress"
      authorize_if relating_to_actor(:user)
    end

    policy action_type([:read, :destroy]) do
      description "Only the related User can read or destroy their Watch Progress"
      authorize_if relates_to_actor_via(:user)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :position_seconds, :float do
      allow_nil? false
      default 0
    end

    attribute :completed, :boolean do
      allow_nil? false
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :user, User do
      public? true
    end

    belongs_to :movie, Movie do
      allow_nil? true
      public? true
    end

    belongs_to :tv_show_episode, TvShowEpisode do
      allow_nil? true
      public? true
    end

    belongs_to :last_media, Media do
      allow_nil? true
      public? true
    end
  end

  identities do
    identity :unique_movie_per_user, [:user_id, :movie_id] do
      where expr(not is_nil(movie_id))
    end

    identity :unique_episode_per_user, [:user_id, :tv_show_episode_id] do
      where expr(not is_nil(tv_show_episode_id))
    end
  end
end
