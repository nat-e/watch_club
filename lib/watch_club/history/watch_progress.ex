defmodule WatchClub.History.WatchProgress do
  @moduledoc """
  A resource that records whether a User has watched a given Movie, TV Show Episode or Sports Event.
  We only create WatchProgress objects for contents that a user has started watching.
  We record the time watched and the time left, through all its Parts, and consider that the content is completed
  when they have watched at least 90% of it. The Part they were in, and where in it, is where Play resumes.
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
  alias WatchClub.Contents.{Book, Content, ContentIdentity, Movie, SportsEvent, TvShowEpisode}
  alias WatchClub.History.Watcher
  alias WatchClub.History.WatchProgress.Actions.{ListWatchers, MarkNotWatched, MarkWatched}
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
      reference :book, index?: true
      reference :movie, on_delete: :delete, index?: true
      reference :tv_show_episode, on_delete: :delete, index?: true
      reference :sports_event, on_delete: :delete, index?: true

      # When the media this refers is deleted, set to nil
      reference :last_media, on_delete: :nilify, index?: true
    end

    # The unique_content_per_user index only serves lookups by user and book (its first columns).
    # These serve the per-user progress lookups of movies and episodes (e.g. Continue Watching).
    custom_indexes do
      index [:user_id, :movie_id]
      index [:user_id, :tv_show_episode_id]
      index [:user_id, :sports_event_id]
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
      description "Marks a single movie, book, episode or Sports Event as watched"
      primary? true

      upsert? true
      upsert_identity :unique_content_per_user

      upsert_fields [
        :position_seconds,
        :last_media_id,
        :duration_seconds,
        :part_number,
        :part_position_seconds
      ]

      accept [:movie_id, :book_id, :tv_show_episode_id, :sports_event_id]

      change set_attribute(:position_seconds, nil)
      change set_attribute(:duration_seconds, nil)
      change set_attribute(:last_media_id, nil)
      change set_attribute(:part_number, nil)
      change set_attribute(:part_position_seconds, nil)
      change relate_actor(:user)
    end

    create :record_progress do
      upsert? true
      upsert_identity :unique_content_per_user

      upsert_fields [
        :position_seconds,
        :last_media_id,
        :duration_seconds,
        :part_number,
        :part_position_seconds
      ]

      accept [
        :book_id,
        :movie_id,
        :tv_show_episode_id,
        :sports_event_id,
        :last_media_id,
        :position_seconds,
        :duration_seconds,
        :part_number,
        :part_position_seconds
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

    action :watchers, {:array, Watcher} do
      description "The other Users who watched a Content or are watching it, the latest first"
      argument :content_identity, ContentIdentity, allow_nil?: false

      run ListWatchers
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

    policy action_type([:update, :destroy]) do
      description "Only the related User can update or destroy their Watch Progress"
      authorize_if relates_to_actor_via(:user)
    end

    policy action_type(:read) do
      description "Every User sees what every User watches"
      authorize_if always()
    end

    policy action([
             :mark_content_watched,
             :mark_content_not_watched,
             :watchers
           ]) do
      description "Any User can mark content watched and see who watched it"
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

    # Every User sees who watched a Content
    publish_all :create, ["history", "global"],
      load: :content,
      transform: &add_content_identity_to_metadata/1

    publish_all :destroy, ["history", "global"],
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

    # How far the User got, in seconds through all the Parts. Nil when marking as watched
    attribute :position_seconds, :float

    # The length of all the Parts together. Nil when marking as watched
    attribute :duration_seconds, :float

    # The Part the User was in, where Play resumes. Nil when marking as watched
    attribute :part_number, :integer do
      constraints min: 1
    end

    # Where the User was in that Part, in seconds. Nil when marking as watched
    attribute :part_position_seconds, :float

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

    belongs_to :sports_event, SportsEvent do
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

    # A content is considered watch when a user has watched 90% of more of it, or marked it as
    # watched, which leaves position_seconds nil. duration_seconds is nil too then, and while the
    # length of one of its files is unknown, which playing it never completes.
    calculate :completed,
              :boolean,
              expr(
                is_nil(position_seconds) or
                  (not is_nil(duration_seconds) and
                     position_seconds / duration_seconds >= @complete_after_ratio)
              )

    # The number of seconds left, through the Parts still to watch
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
    # Returns 100% for media that have been marked watched, and 0% while its length is unknown
    # When more than 90% have been watched, we return 100
    calculate :percent_watched,
              :float,
              expr(
                cond do
                  is_nil(position_seconds) or duration_seconds == 0 ->
                    100.0

                  is_nil(duration_seconds) ->
                    0.0

                  position_seconds / duration_seconds >= @complete_after_ratio ->
                    100.0

                  true ->
                    position_seconds / duration_seconds * 100
                end
              )
  end

  identities do
    identity :unique_content_per_user,
             [:user_id, :book_id, :movie_id, :tv_show_episode_id, :sports_event_id] do
      nils_distinct? false
    end
  end
end
