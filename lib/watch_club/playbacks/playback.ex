defmodule WatchClub.Playbacks.Playback do
  @moduledoc """
  One Media being played by a User inside a Playback Session.

  Persisted in Postgres. A Playback Session has zero or more Playbacks over its
  lifetime; at any moment, a Playback Session has at most one current Playback —
  the one whose `ended_at` is `nil`. Starting a new Playback on a Session ends
  the previous one.

  This resource is concerned only with persistence and lifecycle. HLS
  rendering and its on-disk segment cache live in
  `WatchClub.Playbacks.Playback.Hls` and
  `WatchClub.Playbacks.Playback.SegmentCache`; the cache is reclaimed by
  `WatchClub.Playbacks.Workers.PruneSegmentCache`.
  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Playbacks,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Ash.Expr

  alias WatchClub.MediaCatalog.Media
  alias WatchClub.Playbacks.Session

  postgres do
    table "playbacks"
    repo WatchClub.Repo

    references do
      reference :session, on_delete: :delete, on_update: :update
      reference :media, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, create: [:session_id, :media_id]]

    update :update do
      primary? true
      accept [:last_active_at]
    end

    update :end do
      change set_attribute(:ended_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy actor_absent() do
      description "Playback actions require an actor"
      access_type :strict
      forbid_if always()
    end

    policy action(:create) do
      description "The Instance Administrator can start a Playback for any Media; a User can start one for Media whose Content is visible to them through a Library Item"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if WatchClub.Clubs.Checks.ActorHasAccessToMediaViaLibrary
    end

    policy action_type([:read, :update]) do
      description "Only the starting User (via the parent Session), the Instance Administrator, and the system actor can access Playbacks"
      authorize_if WatchClub.Checks.IsSystemActor
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if expr(session.started_by_id == ^actor(:id))
    end
  end

  preparations do
    prepare build(sort: [inserted_at: :desc])
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :last_active_at, :utc_datetime_usec do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    attribute :ended_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :session, Session do
      allow_nil? false
      public? true
    end

    belongs_to :media, Media do
      allow_nil? false
      public? true
    end
  end
end
