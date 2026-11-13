defmodule WatchClub.Playbacks.Playback do
  @moduledoc """
  One Media being played by a User inside a Playback Session.

  Persisted in Postgres. A Playback Session has zero or more Playbacks over its
  lifetime; at any moment, a Playback Session has at most one current Playback —
  the one whose `ended_at` is `nil`. Starting a new Playback in a Playback Session
  ends the previous one, and so does ending the Playback Session.

  It records the Audio Track and the Text Track it plays, which every Screen starts
  with. HLS rendering and its on-disk segment cache live in
  `WatchClub.Playbacks.Playback.Hls` and `WatchClub.Playbacks.Playback.SegmentCache`;
  the cache is reclaimed by `WatchClub.Playbacks.Workers.EndAbandonedSessions`.
  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Playbacks,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.MediaCatalog.{AudioTrack, Media, TextTrack}
  alias WatchClub.Playbacks.Calculations.TextTrackChoices
  alias WatchClub.Playbacks.Playback.Changes.ChooseStartTracks
  alias WatchClub.Playbacks.Session

  postgres do
    table "playbacks"
    repo WatchClub.Repo

    identity_wheres_to_sql one_current_per_session: "ended_at IS NULL"

    references do
      reference :session, on_delete: :delete, index?: true
      reference :media, on_delete: :delete, index?: true
      reference :audio_track, on_delete: :nilify, index?: true
      reference :text_track, on_delete: :nilify, index?: true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:session_id, :media_id]

      change ChooseStartTracks
    end

    update :end do
      change set_attribute(:ended_at, &DateTime.utc_now/0)
    end

    update :pick_tracks do
      accept [:audio_track_id, :text_track_id]
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

    policy action_type(:read) do
      description "Only the User who started the Playback Session, the Instance Administrator, and the system actor can see Playbacks"
      authorize_if WatchClub.Checks.IsSystemActor
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if relates_to_actor_via([:session, :started_by])
    end

    policy action_type(:update) do
      description "Only the User who started the Playback Session and the system actor change its Playbacks"
      authorize_if WatchClub.Checks.IsSystemActor
      authorize_if relates_to_actor_via([:session, :started_by])
    end
  end

  preparations do
    prepare build(sort: [inserted_at: :desc])
  end

  attributes do
    uuid_v7_primary_key :id

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

    belongs_to :audio_track, AudioTrack do
      public? true
    end

    belongs_to :text_track, TextTrack do
      description "One of its Text Track Choices, or nil for none."
      public? true
    end
  end

  calculations do
    calculate :text_track_choices, :struct, TextTrackChoices do
      description "Its Text Track Choices, and the Forced Text Track that plays with each Audio Track while none is picked."
      constraints instance_of: TextTrackChoices
      public? true
    end
  end

  identities do
    identity :one_current_per_session, [:session_id] do
      where expr(is_nil(ended_at))
      message dgettext_noop("errors", "Something else started playing at the same time")
    end
  end
end
