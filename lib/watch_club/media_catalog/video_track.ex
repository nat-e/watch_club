defmodule WatchClub.MediaCatalog.VideoTrack do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.MediaCatalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.MediaCatalog.Video
  alias WatchClub.MediaCatalog.VideoResolution

  postgres do
    table "video_tracks"
    repo WatchClub.Repo

    references do
      reference :video, on_delete: :delete
    end
  end

  actions do
    defaults [
      :read,
      :destroy,
      update: [:stream_index, :codec, :width, :height, :frame_rate, :bit_rate, :default?]
    ]

    create :create do
      primary? true
      accept [:stream_index, :codec, :width, :height, :frame_rate, :bit_rate, :default?]
    end
  end

  policies do
    policy actor_absent() do
      description "Video track actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:read) do
      description "Any authenticated actor can read Video Tracks"
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      description "Only the system actor can write Video Tracks"
      authorize_if actor_attribute_equals(:system?, true)
    end
  end

  preparations do
    prepare build(load: [:resolution])
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

    attribute :default?, :boolean do
      allow_nil? false
      default false
      public? true
      source :is_default
    end
  end

  relationships do
    belongs_to :video, Video do
      allow_nil? false
      public? true
    end
  end

  calculations do
    # Bucketed display resolution. Cascade is smallest-first with generous height
    # ceilings so anamorphic / letterboxed encodes (e.g. 1920x800 cinemascope)
    # fall into the bucket their width implies rather than the one their
    # cropped height would suggest. Thresholds mirror Jellyfin's
    # `MediaStream.GetResolutionText`, collapsed to the four buckets the UI shows.
    calculate :resolution,
              VideoResolution,
              expr(
                cond do
                  width <= 1024 and height <= 576 -> :sd
                  width <= 1280 and height <= 962 -> :hd_720p
                  width <= 2560 and height <= 1440 -> :hd_1080p
                  true -> :uhd_4k
                end
              ) do
      public? true
    end
  end
end
