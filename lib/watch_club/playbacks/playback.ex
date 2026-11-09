defmodule WatchClub.Playbacks.Playback do
  @moduledoc """
  One Media being played by a User inside a Playback Session.

  Persisted in Postgres. A Playback Session has zero or more Playbacks over its
  lifetime; at any moment, a Playback Session has at most one current Playback —
  the one whose `ended_at` is `nil`. Starting a new Playback on a Session ends
  the previous one, and the Session's `:end_inactive_playbacks` action ends the
  Playbacks whose Player is no longer active.

  This resource is concerned with persistence, lifecycle and the tracks the
  Player starts with. HLS rendering and its on-disk segment cache live in
  `WatchClub.Playbacks.Playback.Hls` and
  `WatchClub.Playbacks.Playback.SegmentCache`; the cache is reclaimed by
  `WatchClub.Playbacks.Workers.PruneSegmentCache`.
  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Playbacks,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.MediaCatalog.Media
  alias WatchClub.Playbacks.Playback.PreferredTrack
  alias WatchClub.Playbacks.Session

  postgres do
    table "playbacks"
    repo WatchClub.Repo

    references do
      reference :session, on_delete: :delete, index?: true
      reference :media, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:session_id, :media_id]
      argument :position_seconds, :float, allow_nil?: true

      change WatchClub.Playbacks.Session.Changes.UpdateWatchProgress
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:last_active_at]
      argument :position_seconds, :float, allow_nil?: true

      change WatchClub.Playbacks.Session.Changes.UpdateWatchProgress
    end

    update :end do
      require_atomic? false
      argument :position_seconds, :float, allow_nil?: true

      change set_attribute(:ended_at, &DateTime.utc_now/0)
      change WatchClub.Playbacks.Session.Changes.UpdateWatchProgress
    end
  end

  policies do
    policy actor_absent() do
      access_type :strict
      forbid_if always()
    end

    policy action(:create) do
      description "The Instance Administrator can play any Media; other Users can play Media with Content"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if expr(not is_nil(media.content_id))
    end

    policy action_type([:read, :update]) do
      description "Only the starting User (via the parent Session), the Instance Administrator, and the system actor can access Playbacks"
      authorize_if WatchClub.Checks.IsSystemActor
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if relates_to_actor_via([:session, :started_by])
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

  calculations do
    calculate :preferred_audio_track_id, :uuid, {PreferredTrack, track: :audio} do
      description "The Audio Track the Player starts with, from the User Preferences."
      public? true
    end

    calculate :preferred_text_track_id, :uuid, {PreferredTrack, track: :text} do
      description "The Text Track the Player starts with, from the User Preferences. Nil for no subtitles."
      public? true
    end
  end
end
