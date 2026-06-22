defmodule WatchClub.ActivityFeed.Event do
  @moduledoc """
  An Ash Resource that describe a single event to display in the activity feed

  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    fragments: [WatchClub.PubSubDefaults]

  alias WatchClub.Accounts.User
  alias WatchClub.ActivityFeed.Calculations.EventPayload
  alias WatchClub.ActivityFeed.EventType
  alias WatchClub.ActivityFeed.Preparations.LoadActivityFeedEvent

  alias WatchClub.ActivityFeed.Events.{
    ClubCreatedEvent,
    ContentAddedEvent,
    LibraryCreatedEvent,
    MemberAddedEvent
  }

  alias WatchClub.Clubs.Checks.ActorIsClubMemberFilter
  alias WatchClub.Clubs.Club

  postgres do
    table "activity_feed_events"
    repo WatchClub.Repo
  end

  pub_sub do
    prefix "activity_feed_events"

    # We don't use publish_all since in the future some events will not be club scoped.
    # The broadcast payload is loaded at creation time (see CreateActivityFeedEvent),
    # so no per-publication `load:` is needed here.
    publish :create_club_created, ["club", :scope_club_id]
    publish :create_library_created, ["club", :scope_club_id]
    publish :create_content_added, ["club", :scope_club_id]
    publish :create_member_added, ["club", :scope_club_id]
  end

  actions do
    defaults [:read]

    read :for_actor do
      description "Get all the Activity feed events for the current user"
      # Filtering is done via the read policy, no need to filter explicitely
      pagination keyset?: true, required?: false, stable_sort: [:id]
      prepare LoadActivityFeedEvent
    end

    read :for_club do
      description "Get all the Activity feed events scoped to a Club"
      argument :club_id, :uuid_v7, allow_nil?: false

      filter expr(scope_club_id == ^arg(:club_id))
      pagination keyset?: true, required?: false, stable_sort: [:id]
      prepare LoadActivityFeedEvent
    end

    create :create_club_created do
      description "Create a :club_created activity feed event"
      argument :club_id, :uuid_v7, allow_nil?: false

      argument :club_created, :map do
        allow_nil? false

        constraints fields: [
                      club_id: [type: :uuid_v7, allow_nil?: false]
                    ]
      end

      change set_attribute(:scope_club_id, arg(:club_id))
      change set_attribute(:type, :club_created)
      change manage_relationship(:club_created, type: :create)
      change relate_actor(:actor, allow_nil?: true)
    end

    create :create_library_created do
      description "Create a :library_created activity feed event"
      argument :club_id, :uuid_v7, allow_nil?: false

      argument :library_created, :map do
        allow_nil? false

        constraints fields: [
                      library_id: [type: :uuid_v7, allow_nil?: false]
                    ]
      end

      change set_attribute(:scope_club_id, arg(:club_id))
      change set_attribute(:type, :library_created)
      change manage_relationship(:library_created, type: :create)
      change relate_actor(:actor, allow_nil?: true)
    end

    create :create_content_added do
      description "Create a :content_added activity feed event"
      argument :club_id, :uuid_v7, allow_nil?: false

      argument :content_added, :map do
        allow_nil? false

        constraints fields: [
                      library_item_id: [type: :uuid_v7, allow_nil?: false]
                    ]
      end

      change set_attribute(:scope_club_id, arg(:club_id))
      change set_attribute(:type, :content_added)
      change manage_relationship(:content_added, type: :create)
      change relate_actor(:actor, allow_nil?: true)
    end

    create :create_member_added do
      description "Create a :member_added activity feed event"
      argument :club_id, :uuid_v7, allow_nil?: false

      argument :member_added, :map do
        allow_nil? false

        constraints fields: [
                      membership_id: [type: :uuid_v7, allow_nil?: false]
                    ]
      end

      change set_attribute(:scope_club_id, arg(:club_id))
      change set_attribute(:type, :member_added)
      change manage_relationship(:member_added, type: :create)
      change relate_actor(:actor, allow_nil?: true)
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

  preparations do
    prepare build(sort: [created_at: :desc])
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :type, EventType do
      allow_nil? false
    end

    create_timestamp :created_at
  end

  relationships do
    # An activity can have 3 scopes:
    # - User: It only concerns this given User (e.g. a ContentRequest has completed)
    # - Club: It concerns all members of a Club (e.g. a Content was added to the Club's library)
    # - Global: It concerns all Users (Not used yet, perhaps a global change on the instance?).
    #   In this case both scopes will be nil
    belongs_to :scope_user, User
    belongs_to :scope_club, Club

    # The User that triggerred Event. Nil when the event was created from a system action.
    belongs_to :actor, User

    # Polymorphism, each Event will have one relationship populated depending on its type
    # Records share the same primary ID
    # Accessed through the :payload calculation
    has_one :club_created, ClubCreatedEvent, destination_attribute: :id
    has_one :library_created, LibraryCreatedEvent, destination_attribute: :id
    has_one :content_added, ContentAddedEvent, destination_attribute: :id
    has_one :member_added, MemberAddedEvent, destination_attribute: :id
  end

  calculations do
    # A ClubCreatedEvent | ClubCreatedEvent | ContentAddedEvent | MemberAddedEvent
    calculate :payload, :struct, EventPayload do
      allow_nil? false
    end
  end
end
