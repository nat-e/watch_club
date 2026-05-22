defmodule WatchClub.Media.TextTrack do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Media.Video
  alias WatchClub.Shared.Changes.NormalizePath

  postgres do
    table "text_tracks"
    repo WatchClub.Repo

    references do
      reference :video, on_delete: :delete, on_update: :update
    end

    check_constraints do
      check_constraint [:stream_index, :sidecar_path],
        name: "text_tracks_exactly_one_text_track_source_check",
        check: "num_nonnulls(stream_index, sidecar_path) = 1",
        message: "Text Track must be embedded or provided by a sidecar file"
    end
  end

  actions do
    defaults [:read, :destroy, update: [:stream_index, :sidecar_path, :codec, :language, :title, :default?, :forced?]]

    create :create do
      primary? true
      accept [:stream_index, :sidecar_path, :codec, :language, :title, :default?, :forced?]

      change {NormalizePath, attribute: :sidecar_path}
    end
  end

  policies do
    policy actor_absent() do
      description "Text track actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:read) do
      description "Any authenticated actor can read Text Tracks"
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      description "Only the system actor can write Text Tracks"
      authorize_if actor_attribute_equals(:system?, true)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :stream_index, :integer do
      allow_nil? true
      public? true
      constraints min: 0
    end

    attribute :sidecar_path, :string do
      allow_nil? true
      public? true
    end

    attribute :codec, :string do
      allow_nil? false
      public? true
    end

    attribute :language, :string do
      allow_nil? true
      public? true
    end

    attribute :title, :string do
      allow_nil? true
      public? true
    end

    attribute :default?, :boolean do
      allow_nil? false
      default false
      public? true
      source :is_default
    end

    attribute :forced?, :boolean do
      allow_nil? false
      default false
      public? true
      source :is_forced
    end
  end

  relationships do
    belongs_to :video, Video do
      allow_nil? false
      public? true
    end
  end
end
