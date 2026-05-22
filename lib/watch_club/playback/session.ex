defmodule WatchClub.Playback.Session do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Playback,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Ash.Expr

  alias WatchClub.Accounts.User
  alias WatchClub.Media.Media

  postgres do
    table "playback_sessions"
    repo WatchClub.Repo

    references do
      reference :started_by, on_delete: :nilify, on_update: :update
      reference :media, on_delete: :nilify, on_update: :update
    end
  end

  actions do
    defaults [:read]

    read :for_playback do
      get? true

      prepare fn query, _context ->
        Ash.Query.after_action(query, fn _query, records ->
          Ash.load(
            records,
            [media: [video: [:video_tracks, :audio_tracks, :text_tracks]]],
            actor: WatchClub.SystemActor.actor()
          )
        end)
      end
    end

    create :start do
      primary? true
      accept [:media_id]

      validate present(:media_id)

      change relate_actor(:started_by)
    end

    update :heartbeat do
      accept []
      change atomic_update(:last_active_at, expr(now()))
    end
  end

  policies do
    policy actor_absent() do
      description "Playback Session actions require an actor"
      access_type :strict
      forbid_if always()
    end

    policy action(:start) do
      description "The Instance Administrator can start a Playback Session for any Media; a User can start one for Media whose Content is visible to them through a Library Item"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if WatchClub.Clubs.Checks.ActorHasAccessToMediaViaLibrary
    end

    policy action([:read, :for_playback, :heartbeat]) do
      description "Only the starting User and Instance Administrator can access Playback Sessions"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if relates_to_actor_via(:started_by)
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

    timestamps()
  end

  relationships do
    belongs_to :started_by, User do
      allow_nil? true
      public? true
    end

    belongs_to :media, Media do
      allow_nil? true
      public? true
    end
  end
end
