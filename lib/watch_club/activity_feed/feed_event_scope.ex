defmodule WatchClub.ActivityFeed.FeedEventScope do
  @moduledoc """
  A single scope (visibility) row for an activity feed event.

  An event (ClubCreatedEvent, ContentAddedEvent, ContentWatchedEvent, ...) fans out to one or more
  scopes. A scope determines *who* sees the event:
  - User: only this user (e.g. their own `content_watched` event)
  - Club: all members of a Club (e.g. a Content added to the Club's library)
  - Global: both scopes nil (not used yet)

  FeedEventScope is thin: it carries the scope, a denormalized `content` selection key (so the
  content-detail feed can filter by Content without joining through the polymorphic event), the
  `group_key` of its Feed Entry (see `WatchClub.ActivityFeed.FeedEntry`), and a nullable FK to
  exactly one event (enforced by a DB check constraint). The `event` calculation resolves the
  populated event. Deleting an event cascade-deletes its scopes via the per-type FK
  `on_delete: :delete` — this replaces the previous shared-PK + trigger machinery.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Accounts.User
  alias WatchClub.ActivityFeed.Calculations.ScopeEvent
  alias WatchClub.ActivityFeed.Changes.SetGroupKey
  alias WatchClub.ActivityFeed.Preparations.{DistinctPerEvent, LoadActivityFeedEvent}

  alias WatchClub.ActivityFeed.Events.{
    ClubCreatedEvent,
    ContentAddedEvent,
    ContentWatchedEvent,
    LibraryCreatedEvent,
    MemberAddedEvent
  }

  alias WatchClub.Clubs.Checks.ActorIsClubMemberFilter
  alias WatchClub.Clubs.Club
  alias WatchClub.Contents.{Content, ContentIdentity, ExternalIdSource}
  alias WatchClub.Contents.Preparations.FilterByContentIdentities

  postgres do
    table "activity_feed_scopes"
    repo WatchClub.Repo

    references do
      # Cascade deletes the scope when its scope object gets deleted
      reference :scope_user, on_delete: :delete
      reference :scope_club, on_delete: :delete

      # Denormalized selection key, cascades from the Content
      reference :content, on_delete: :delete

      # Delete the scope when its event get deleted
      reference :club_created_event, on_delete: :delete
      reference :library_created_event, on_delete: :delete
      reference :content_added_event, on_delete: :delete
      reference :member_added_event, on_delete: :delete
      reference :content_watched_event, on_delete: :delete
    end

    check_constraints do
      check_constraint [
                         :club_created_event_id,
                         :content_added_event_id,
                         :content_watched_event_id,
                         :library_created_event_id,
                         :member_added_event_id
                       ],
                       check:
                         "num_nonnulls(club_created_event_id, content_added_event_id, content_watched_event_id, library_created_event_id, member_added_event_id) = 1",
                       name: "activity_feed_scopes_exactly_one_event_check",
                       message: "A feed scope must reference exactly one event"
    end

    custom_indexes do
      # text_pattern_ops serves both the Feed Entry joins (=) and SetGroupKey's prefix LIKE
      index ["group_key text_pattern_ops"], name: "activity_feed_scopes_group_key_index"
    end
  end

  actions do
    # :update is required so the event's `manage_relationship(:scopes, :direct_control)` can reconcile.
    defaults [:read, :update, :destroy]

    create :create do
      primary? true
      accept [:scope_user_id, :scope_club_id, :content_id]

      argument :group, :string do
        allow_nil? false
        description "Who did what, such as `watched:<user id>`. See SetGroupKey."
      end

      change SetGroupKey
    end

    read :distinct_per_event do
      description "One scope per event, for events visible through several scopes"
      prepare DistinctPerEvent
    end

    read :for_content do
      description "Get the distinct Activity feed events about a Content, potentially filtered by Club"
      argument :content_identity, ContentIdentity, allow_nil?: false
      argument :club_id, :uuid_v7, allow_nil?: true

      prepare {FilterByContentIdentities, content_path: [:content]}

      # Filter by club if one is provided
      filter expr(is_nil(^arg(:club_id)) or scope_club_id == ^arg(:club_id))

      pagination keyset?: true, required?: false, stable_sort: [:id]
      prepare DistinctPerEvent
      prepare LoadActivityFeedEvent
    end
  end

  policies do
    policy action_type(:read) do
      description "Users can read events that are global, scoped to themselves, or to a club they're a member of"
      authorize_if relates_to_actor_via(:scope_user)
      authorize_if {ActorIsClubMemberFilter, club_path: [:scope_club]}
      authorize_if expr(is_nil(scope_club) and is_nil(scope_user))
      forbid_if always()
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub
    prefix "feed"

    # Each scope row has exactly one routing key (or both nil for global). Ash skips a publication
    # whose key field is nil, so a club scope only hits feed:club:{id} and a personal scope only
    # hits feed:user:{id}. Subscribers reload the scope's Feed Entry. Destroys are published too, so
    # an entry shrinks when one of its events moves to another entry. Scopes deleted by a database
    # cascade, such as when content is removed from a library, aren't published.
    publish_all :create, ["club", :scope_club_id]
    publish_all :create, ["user", :scope_user_id]
    publish_all :destroy, ["club", :scope_club_id]
    publish_all :destroy, ["user", :scope_user_id]

    # We also publish on a feed content topic for the Content details page
    publish_all :create, ["content", :content_external_id_source, :content_external_id],
      load: [:content_external_id_source, :content_external_id]
  end

  preparations do
    prepare build(sort: [created_at: :desc])
  end

  attributes do
    uuid_v7_primary_key :id

    # The Feed Entry this scope's event belongs to, set by SetGroupKey
    attribute :group_key, :string, allow_nil?: false

    create_timestamp :created_at
  end

  relationships do
    # A scope concerns either a single User, all members of a Club, or all Users (both nil, unused yet).
    belongs_to :scope_user, User, allow_nil?: true
    belongs_to :scope_club, Club, allow_nil?: true

    # Denormalized selection key for the content-detail feed. Nil for events without a Content
    # (club_created, library_created, member_added).
    belongs_to :content, Content, allow_nil?: true

    # Polymorphism: exactly one is set (enforced by the check constraint). Accessed via :event.
    belongs_to :club_created_event, ClubCreatedEvent, allow_nil?: true
    belongs_to :library_created_event, LibraryCreatedEvent, allow_nil?: true
    belongs_to :content_added_event, ContentAddedEvent, allow_nil?: true
    belongs_to :member_added_event, MemberAddedEvent, allow_nil?: true
    belongs_to :content_watched_event, ContentWatchedEvent, allow_nil?: true
  end

  calculations do
    # The non-nil event:
    # ClubCreatedEvent | LibraryCreatedEvent | ContentAddedEvent | MemberAddedEvent | ContentWatchedEvent
    calculate :event, :struct, ScopeEvent do
      allow_nil? false
      argument :load, :term
    end

    # The external_id and external_id_source of the Content, if non null
    # This is used internally to compute the Content pubsub topic
    calculate :content_external_id_source, ExternalIdSource, expr(content.external_id_source)
    calculate :content_external_id, :string, expr(content.external_id)
  end
end
