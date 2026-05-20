defmodule WatchClub.Media.AudioTrack do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Media.Video

  postgres do
    table "audio_tracks"
    repo(WatchClub.Repo)

    references do
      reference(:video, on_delete: :delete, on_update: :update)
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:stream_index, :codec, :language, :title, :channels, :default?]
    end
  end

  policies do
    policy actor_absent() do
      description "Audio track actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action([:read, :create]) do
      description "Only the Instance Administrator can manage Audio Tracks directly"
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

    attribute :language, :string do
      allow_nil? true
      public? true
    end

    attribute :title, :string do
      allow_nil? true
      public? true
    end

    attribute :channels, :integer do
      allow_nil? true
      public? true
      constraints min: 1
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
end
