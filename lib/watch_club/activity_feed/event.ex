defmodule WatchClub.ActivityFeed.Event do
  @moduledoc """
  An Ash Resource that describe a single event to display in the activity feed.
  It contains the fields and relationships common to all Events.
  Fields and relationships specific to a certain event type are declared in a
  type-specific payload resource.

  We do not create Events for update/removal, and Events get deleted when the objects they describe
  are deleted.
  This is why payloads contain references to the objects they describe (Club, LibraryItem, ...),
  not snapshots.

  Event and their payload share the same ID, the FK is set on the payload object and we use a custom
  SQL trigger to cascade delete the Events when the payload gets deleted
  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

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
  alias WatchClub.Contents.{Content, ContentIdentity}
  alias WatchClub.Contents.Preparations.FilterByContentIdentities

  postgres do
    table "activity_feed_events"
    repo WatchClub.Repo

    references do
      # Cascade deletes the events when their scope gets deleted
      reference :scope_user, on_delete: :delete
      reference :scope_club, on_delete: :delete

      reference :content, on_delete: :delete

      # Set the actor to nil when deleted
      reference :actor, on_delete: :nilify
    end

    # Each payload row shares its primary key with its parent event. The FK
    # cascade only deletes the payload when the event is deleted, not the other
    # way around. These AFTER DELETE triggers delete the parent event whenever any
    # payload is deleted, covering every deletion path (including DB cascades).
    custom_statements do
      statement :delete_parent_event_function do
        up """
        CREATE OR REPLACE FUNCTION delete_parent_activity_feed_event()
        RETURNS TRIGGER LANGUAGE plpgsql AS $$
        BEGIN
          DELETE FROM activity_feed_events WHERE id = OLD.id;
          RETURN OLD;
        END;
        $$
        """

        down "DROP FUNCTION IF EXISTS delete_parent_activity_feed_event()"
      end

      statement :delete_parent_event_on_club_created do
        up """
        CREATE TRIGGER delete_parent_event
        AFTER DELETE ON activity_feed_club_created_events
        FOR EACH ROW EXECUTE FUNCTION delete_parent_activity_feed_event()
        """

        down "DROP TRIGGER IF EXISTS delete_parent_event ON activity_feed_club_created_events"
      end

      statement :delete_parent_event_on_library_created do
        up """
        CREATE TRIGGER delete_parent_event
        AFTER DELETE ON activity_feed_library_created_events
        FOR EACH ROW EXECUTE FUNCTION delete_parent_activity_feed_event()
        """

        down "DROP TRIGGER IF EXISTS delete_parent_event ON activity_feed_library_created_events"
      end

      statement :delete_parent_event_on_content_added do
        up """
        CREATE TRIGGER delete_parent_event
        AFTER DELETE ON activity_feed_content_added_events
        FOR EACH ROW EXECUTE FUNCTION delete_parent_activity_feed_event()
        """

        down "DROP TRIGGER IF EXISTS delete_parent_event ON activity_feed_content_added_events"
      end

      statement :delete_parent_event_on_member_added do
        up """
        CREATE TRIGGER delete_parent_event
        AFTER DELETE ON activity_feed_member_added_events
        FOR EACH ROW EXECUTE FUNCTION delete_parent_activity_feed_event()
        """

        down "DROP TRIGGER IF EXISTS delete_parent_event ON activity_feed_member_added_events"
      end
    end
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

    read :for_content do
      description "Get all the Activity feed events about a Content, potentially filtered by Club"
      argument :content_identity, ContentIdentity, allow_nil?: false
      argument :club_id, :uuid_v7, allow_nil?: true

      prepare {FilterByContentIdentities, content_path: [:content]}

      # Filter by club if one is provided
      filter expr(is_nil(^arg(:club_id)) or scope_club_id == ^arg(:club_id))

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
      argument :content_id, :uuid_v7, allow_nil?: false

      argument :content_added, :map do
        allow_nil? false

        constraints fields: [
                      library_item_id: [type: :uuid_v7, allow_nil?: false]
                    ]
      end

      change set_attribute(:content_id, arg(:content_id))
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

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub
    prefix "feed"

    # We don't use publish_all since in the future some events will not be club scoped.
    # The broadcast payload is loaded at creation time (see CreateActivityFeedEvent),
    # so no per-publication `load:` is needed here.
    publish :create_club_created, ["club", :scope_club_id]
    publish :create_library_created, ["club", :scope_club_id]
    publish :create_content_added, ["club", :scope_club_id]
    publish :create_member_added, ["club", :scope_club_id]
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
    belongs_to :scope_user, User, allow_nil?: true
    belongs_to :scope_club, Club, allow_nil?: true

    # The User that triggerred Event. Nil when the event was created from a system action.
    belongs_to :actor, User, allow_nil?: true

    # The Content this event is related to (only for some events)
    belongs_to :content, Content, allow_nil?: true

    # Polymorphism, each Event will have one relationship populated depending on its type
    # Records share the same primary ID
    # Accessed through the :payload calculation
    has_one :club_created, ClubCreatedEvent, allow_nil?: true, destination_attribute: :id
    has_one :library_created, LibraryCreatedEvent, allow_nil?: true, destination_attribute: :id
    has_one :content_added, ContentAddedEvent, allow_nil?: true, destination_attribute: :id
    has_one :member_added, MemberAddedEvent, allow_nil?: true, destination_attribute: :id
  end

  calculations do
    # A ClubCreatedEvent | ClubCreatedEvent | ContentAddedEvent | MemberAddedEvent
    calculate :payload, :struct, EventPayload do
      allow_nil? false
    end
  end
end
