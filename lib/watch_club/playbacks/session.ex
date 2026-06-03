defmodule WatchClub.Playbacks.Session do
  @moduledoc """
  Aggregate root for the Playback domain. Owns the lifecycle of its Playbacks.

  All public lifecycle actions live here: starting a Playback Session,
  switching to a new Playback inside it, heartbeating the current Playback,
  and closing it. Every public action returns the Session with its
  `:active_playback` loaded (with the HLS-rendering Media graph), or `nil`
  when the Session has no active Playback.
  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Playbacks,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Ash.Expr

  require Ash.Query

  alias WatchClub.Accounts.User
  alias WatchClub.MediaCatalog.TextTrack
  alias WatchClub.Playbacks.Playback
  alias WatchClub.Playbacks.Session.Changes

  postgres do
    table "playback_sessions"
    repo WatchClub.Repo

    references do
      reference :started_by, on_delete: :nilify, on_update: :update
    end
  end

  actions do
    defaults [:read]

    read :read_for_playback do
      description "Read a Session by id with `:active_playback` loaded HLS-ready. Used by the HLS controller to authorize and serve segments."
      get? true

      prepare build(
                load: [
                  active_playback: [
                    media: [
                      video: [
                        :default_video_track,
                        audio_tracks: [:display_label],
                        text_tracks:
                          TextTrack
                          |> Ash.Query.filter(hls_supported? == true)
                          |> Ash.Query.load(:display_label)
                      ]
                    ]
                  ]
                ]
              )
    end

    create :start do
      description "Create a Playback Session and start its first Playback for the selected Media."
      argument :media_id, :uuid_v7, allow_nil?: false

      change relate_actor(:started_by)
      change manage_relationship(:media_id, :playbacks, type: :create, value_is_key: :media_id)
      change Changes.LoadActivePlayback
    end

    update :start_new_playback do
      description "End the current Playback on this Session and start a new one for the selected Media."

      require_atomic? false
      argument :media_id, :uuid_v7, allow_nil?: false

      change Changes.EndCurrentPlayback
      change Changes.StartPlayback
      change Changes.LoadActivePlayback
    end

    update :heartbeat do
      description "Heartbeat the Session's current Playback, updating its last active time and the actor's Watch Progress from the reported position."

      require_atomic? false
      argument :position_seconds, :float, allow_nil?: true

      change Changes.BumpCurrentPlayback
      change Changes.LoadActivePlayback
    end

    update :close do
      description "Close the Session's current Playback by setting its `ended_at`, recording the actor's Watch Progress from the final position. Its on-disk segment cache is reclaimed by the periodic prune worker."

      require_atomic? false
      argument :position_seconds, :float, allow_nil?: true

      change Changes.EndCurrentPlayback
      change Changes.LoadActivePlayback
    end
  end

  policies do
    policy actor_absent() do
      description "Playback Session actions require an actor"
      access_type :strict
      forbid_if always()
    end

    policy action(:start) do
      description "Any authenticated User can start a Playback Session; visibility of the selected Media is checked when the first Playback is created."
      authorize_if always()
    end

    policy action_type(:read) do
      description "Only the starting User and Instance Administrator can access Playback Sessions"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if relates_to_actor_via(:started_by)
    end

    policy action([:start_new_playback, :heartbeat, :close]) do
      description "Only the starting User and the Instance Administrator can act on a Playback Session."
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if relates_to_actor_via(:started_by)
    end
  end

  preparations do
    prepare build(sort: [inserted_at: :desc])
  end

  attributes do
    uuid_v7_primary_key :id

    timestamps()
  end

  relationships do
    belongs_to :started_by, User do
      allow_nil? true
      public? true
    end

    has_many :playbacks, Playback do
      public? true
    end

    has_one :active_playback, Playback do
      public? true
      filter expr(is_nil(ended_at))
    end
  end
end
