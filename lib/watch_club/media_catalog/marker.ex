defmodule WatchClub.MediaCatalog.Marker do
  @moduledoc """
  A part of a Video that the Player lets a User skip: its Intro, Recap or Credits.
  `WatchClub.MediaCatalog.Video.Changes.DetectMarkers` finds them.
  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.MediaCatalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.MediaCatalog.{MarkerKind, Video}

  postgres do
    table "markers"
    repo WatchClub.Repo

    references do
      # The unique_kind_per_video index starts with video_id
      reference :video, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, create: [:video_id, :kind, :start_seconds, :end_seconds]]
  end

  policies do
    policy actor_absent() do
      description "Marker actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:read) do
      description "Any authenticated actor can read Markers"
      authorize_if always()
    end

    policy action_type([:create, :destroy]) do
      description "Only the system actor can write Markers"
      authorize_if actor_attribute_equals(:system?, true)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :kind, MarkerKind do
      allow_nil? false
      public? true
    end

    attribute :start_seconds, :float do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :end_seconds, :float do
      allow_nil? false
      public? true
      constraints min: 0
    end
  end

  relationships do
    belongs_to :video, Video do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_kind_per_video, [:video_id, :kind]
  end
end
