defmodule WatchClub.Media.Video do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Contents.{Movie, TvShowEpisode}
  alias WatchClub.Media.{AudioTrack, Media, TextTrack, VideoTrack}

  postgres do
    table "videos"
    repo(WatchClub.Repo)

    references do
      reference(:media, on_delete: :delete, on_update: :update)
      reference(:movie, on_delete: :restrict, on_update: :update)
      reference(:tv_show_episode, on_delete: :restrict, on_update: :update)
    end

    check_constraints do
      check_constraint([:movie_id, :tv_show_episode_id],
        name: "videos_exactly_one_content_attachment_check",
        check: "num_nonnulls(movie_id, tv_show_episode_id) = 1",
        message: "Video must be attached to exactly one Movie or TV Show Episode"
      )
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:movie_id, :tv_show_episode_id, :duration_seconds, :container, :bit_rate]

      argument :video_tracks, {:array, :map} do
        allow_nil? false
        constraints min_length: 1
      end

      argument :audio_tracks, {:array, :map} do
        allow_nil? false
        default []
      end

      argument :text_tracks, {:array, :map} do
        allow_nil? false
        default []
      end

      change manage_relationship(:video_tracks, type: :create, authorize?: false)
      change manage_relationship(:audio_tracks, type: :create, authorize?: false)
      change manage_relationship(:text_tracks, type: :create, authorize?: false)
    end
  end

  policies do
    policy actor_absent() do
      description "Video actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action([:read, :create, :destroy]) do
      description "Only the Instance Administrator can manage Videos directly"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  attributes do
    attribute :id, :uuid_v7 do
      primary_key? true
      allow_nil? false
      public? true
    end

    attribute :duration_seconds, :float do
      allow_nil? true
      public? true
    end

    attribute :container, :string do
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
    belongs_to :media, Media do
      primary_key? true
      allow_nil? false
      define_attribute? false
      source_attribute :id
    end

    belongs_to :movie, Movie do
      allow_nil? true
      public? true
    end

    belongs_to :tv_show_episode, TvShowEpisode do
      allow_nil? true
      public? true
    end

    has_many :video_tracks, VideoTrack do
      public? true
    end

    has_many :audio_tracks, AudioTrack do
      public? true
    end

    has_many :text_tracks, TextTrack do
      public? true
    end
  end

  identities do
    identity :unique_media, [:id]
  end
end
