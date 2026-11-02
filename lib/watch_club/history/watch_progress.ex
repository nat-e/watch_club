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
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Accounts.User
  alias WatchClub.ActivityFeed.Changes.ScheduleContentWatchedEventSync
  alias WatchClub.Contents.{Book, Content, ContentIdentity, Movie, TvShowEpisode}
  alias WatchClub.History.WatchProgress.Actions.{MarkNotWatched, MarkWatched}
  alias WatchClub.MediaCatalog.Media

  # When a user has watched more than 90% of a media, we consider it fully watched
  @complete_after_ratio 0.9

  postgres do
    table "watch_progresses"
    repo WatchClub.Repo

    identity_wheres_to_sql unique_movie_per_user: "movie_id IS NOT NULL",
                           unique_book_per_user: "book_id IS NOT NULL",
                           unique_episode_per_user: "tv_show_episode_id IS NOT NULL"

    references do
      reference :user, on_delete: :delete
      reference :movie, on_delete: :delete
      reference :tv_show_episode, on_delete: :delete

      # When the media this refers is deleted, set to nil
      reference :last_media, on_delete: :nilify
    end

    # The unique_content_per_user index only serves lookups by user and book (its first columns).
    # These serve the per-user progress lookups of movies and episodes (e.g. Continue Watching).
    custom_indexes do
      index [:user_id, :movie_id]
      index [:user_id, :tv_show_episode_id]
    end
  end

  actions do
    # :destroy stays atomic; MarkNotWatched recomputes the ContentWatchedEvent after the bulk delete.
    defaults [:read, :destroy]

    # Mark watched is only intended to use by the generic mark_*_watched actions.
    # It does not trigger side-effect to stay atomic to keep marking a show with many
    # episodes watched fast.
    # Side effects are triggered once per batch on the generic actions
    create :mark_watched do
      description "Marks a single movie, book or episode as watched"
      primary? true

      upsert? true
      upsert_identity :unique_content_per_user
      upsert_fields [:position_seconds, :last_media_id, :duration_seconds]
      accept [:movie_id, :book_id, :tv_show_episode_id]

      change set_attribute(:position_seconds, nil)
      change set_attribute(:duration_seconds, nil)
      change set_attribute(:last_media_id, nil)
      change relate_actor(:user)
    end

    create :record_progress do
      upsert? true
      upsert_identity :unique_content_per_user
      upsert_fields [:position_seconds, :last_media_id, :duration_seconds]

      accept [
        :book_id,
        :movie_id,
        :tv_show_episode_id,
        :last_media_id,
        :position_seconds,
        :duration_seconds
      ]

      change relate_actor(:user)
      change ScheduleContentWatchedEventSync
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

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # Notify every change to the User's content topic
    # Bulk actions only trigger a single notification (see MarkWatched and MarkNotWatched)
    # We add :content_id and :content_identity in the metadata to make
    # it easy for subscribers to know which media this is related to
    publish_all :create, ["content", "user", :user_id],
      load: :content,
      transform: &add_content_identity_to_metadata/1

    publish_all :destroy, ["content", "user", :user_id],
      load: :content,
      transform: &add_content_identity_to_metadata/1

    defp add_content_identity_to_metadata(%Ash.Notifier.Notification{} = notification) do
      content = notification.data.calculations[:content]

      %{
        notification
        | metadata:
            notification.metadata
            |> Map.put(:content_identity, ContentIdentity.from_content(content))
            |> Map.put(:content_id, content.id)
      }
    end
  end

  preparations do
    # We always load the simple calculations that don't require joins
    prepare build(load: [:seconds_left, :percent_watched, :completed])
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
    # The content this Watch Progress is related to
    # This is used internally to set the ContentIdentity in the metadata
    # of the Notifications sent on PubSub.
    calculate :content,
              :struct,
              WatchClub.History.Calculations.WatchProgressContent do
      constraints instance_of: Content
      allow_nil? false
      public? false
    end

    # A content is considered watch when a user has watched 90% of more of it
    # position_seconds and duration_seconds will be nil when the content is marked as watched.
    calculate :completed,
              :boolean,
              expr(
                is_nil(position_seconds) or is_nil(duration_seconds) or
                  position_seconds / duration_seconds >= @complete_after_ratio
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

    # The percentage of the media that has been watched
    # Returns 100% for media that have been marked watched
    # When more than 90% have been watched, we return 100
    calculate :percent_watched,
              :float,
              expr(
                cond do
                  is_nil(position_seconds) or is_nil(duration_seconds) or duration_seconds == 0 ->
                    100.0

                  position_seconds / duration_seconds >= @complete_after_ratio ->
                    100.0

                  true ->
                    position_seconds / duration_seconds * 100
                end
              )
  end

  identities do
    identity :unique_content_per_user, [:user_id, :book_id, :movie_id, :tv_show_episode_id] do
      nils_distinct? false
    end
  end
end
