defmodule WatchClub.History.WatchProgress do
  @moduledoc """
  A resource that records whether a User has watched a given Movie or TV Show Episode.
  We only create WatchProgress objects for contents that a user has started watching.
  We record the time watched and the time left, and consider that the content is completed when they have watched
  at least 90% of the content.
  It is also possible for user to "Mark as Watched" without watching. In this case, position_seconds and duration_seconds
  are set to nil, and the content is considered watched.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.History,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [WatchClub.Contents.Notifiers.ContentChangedNotifier]

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.{Book, Content, ContentIdentity, Movie, TvShowEpisode}
  alias WatchClub.History.WatchProgress.Actions.{MarkNotWatched, MarkWatched}
  alias WatchClub.MediaCatalog.Media

  postgres do
    table "watch_progresses"
    repo WatchClub.Repo

    identity_wheres_to_sql unique_movie_per_user: "movie_id IS NOT NULL",
                           unique_book_per_user: "book_id IS NOT NULL",
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
      upsert_fields [:position_seconds, :last_media_id, :duration_seconds]

      accept [:movie_id, :last_media_id, :position_seconds, :duration_seconds]
      change relate_actor(:user)
    end

    create :record_book_progress do
      upsert? true
      upsert_identity :unique_book_per_user
      upsert_fields [:position_seconds, :last_media_id, :duration_seconds]

      accept [:book_id, :last_media_id, :position_seconds, :duration_seconds]
      change relate_actor(:user)
    end

    create :record_episode_progress do
      upsert? true
      upsert_identity :unique_episode_per_user
      upsert_fields [:position_seconds, :last_media_id, :duration_seconds]

      accept [:tv_show_episode_id, :last_media_id, :position_seconds, :duration_seconds]
      change relate_actor(:user)
    end

    action :mark_content_watched, :struct do
      constraints instance_of: Content
      argument :content_identity, ContentIdentity, allow_nil?: false
      argument :season_number, :integer
      argument :episode_number, :integer

      run MarkWatched
    end

    action :mark_content_not_watched, :struct do
      constraints instance_of: Content
      argument :content_identity, ContentIdentity, allow_nil?: false
      argument :season_number, :integer
      argument :episode_number, :integer

      run MarkNotWatched
    end
  end

  policies do
    policy actor_absent() do
      description "WatchProgress actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:create) do
      description "Any User can record WatchProgress"
      authorize_if relating_to_actor(:user)
    end

    policy action_type([:read, :update, :destroy]) do
      description "Only the related User can read or destroy their Watch Progress"
      authorize_if relates_to_actor_via(:user)
    end

    policy action([
             :mark_content_watched,
             :mark_content_not_watched
           ]) do
      description "Any User can mark content watched"
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id

    # The number of seconds that the User has watched on a Media. Nil when marking as watched
    attribute :position_seconds, :float

    # The total duration of the Media that was being watched by the User. Nil when marking as watched
    attribute :duration_seconds, :float

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

    belongs_to :book, Book do
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

  calculations do
    # A content is considered watch when a user has watched 90% of more of it
    # position_seconds and duration_seconds will be nil when the content is marked as watched.
    calculate :completed,
              :boolean,
              expr(
                is_nil(position_seconds) or is_nil(duration_seconds) or
                  position_seconds / duration_seconds >= 0.9
              )

    # The number of seconds left. This will always be positive since it's computed on the same Media
    calculate :seconds_left,
              :float,
              expr(
                if is_nil(position_seconds) or is_nil(duration_seconds) do
                  nil
                else
                  duration_seconds - position_seconds
                end
              )
  end

  identities do
    identity :unique_book_per_user, [:user_id, :book_id] do
      where expr(not is_nil(book_id))
    end

    identity :unique_movie_per_user, [:user_id, :movie_id] do
      where expr(not is_nil(movie_id))
    end

    identity :unique_episode_per_user, [:user_id, :tv_show_episode_id] do
      where expr(not is_nil(tv_show_episode_id))
    end
  end
end
