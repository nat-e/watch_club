defmodule WatchClub.Media.VideoTrack do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Media.Video

  postgres do
    table "video_tracks"
    repo(WatchClub.Repo)

    references do
      reference(:video, on_delete: :delete, on_update: :update)
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:stream_index, :codec, :width, :height, :frame_rate, :bit_rate]
    end
  end

  policies do
    policy actor_absent() do
      description "Video track actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action([:read, :create, :destroy]) do
      description "Only the Instance Administrator can manage Video Tracks directly"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :stream_index, :integer do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :codec, :string do
      allow_nil? false
      public? true
    end

    attribute :width, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :height, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :frame_rate, :float do
      allow_nil? true
      public? true
    end

    attribute :bit_rate, :integer do
      allow_nil? true
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
end
