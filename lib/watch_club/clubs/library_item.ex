defmodule WatchClub.Clubs.LibraryItem do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.Checks.ActorIsClubMember
  alias WatchClub.Clubs.Checks.ActorIsClubMemberFilter
  alias WatchClub.Clubs.Club
  alias WatchClub.Contents.Content

  postgres do
    table "library_items"
    repo(WatchClub.Repo)

    references do
      reference(:club, on_delete: :delete, on_update: :update)
      reference(:added_by, on_delete: :nilify, on_update: :update)
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:club_id, :content_id]

      change relate_actor(:added_by)
    end
  end

  policies do
    policy actor_absent() do
      description "Library items actions must have an actor"
      access_type :strict
      forbid_if always()
    end

    policy action([:destroy]) do
      description "Only admins or members that have added the content can remove it"
      authorize_if {ActorIsClubMemberFilter, role: :admin}
      authorize_if relates_to_actor_via(:added_by)
    end

    policy action([:create]) do
      description "Only club members can create library items"
      authorize_if ActorIsClubMember
    end

    policy action([:read]) do
      description "Only club members can read library items"
      authorize_if ActorIsClubMemberFilter
    end
  end

  attributes do
    uuid_v7_primary_key :id

    timestamps()
  end

  relationships do
    belongs_to :club, Club do
      public? true
      allow_nil? false
    end

    belongs_to :content, Content do
      public? true
      allow_nil? false
    end

    belongs_to :added_by, User do
      public? true
    end
  end

  identities do
    identity :club_and_content, [:club_id, :content_id]
  end
end
