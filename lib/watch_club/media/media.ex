defmodule WatchClub.Media.Media do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Media.{Audiobook, Ebook, ImportRun, MediaType, Video}
  alias WatchClub.Shared.Changes.NormalizePath

  postgres do
    table "media"
    repo WatchClub.Repo

    references do
      reference :last_successful_media_import, on_delete: :nilify, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create_video do
      primary? true
      accept [:path]

      argument :video, :map do
        allow_nil? false
      end

      change set_attribute(:type, :video)
      change NormalizePath
      change manage_relationship(:video, type: :create, authorize?: false)
    end

    create :create_ebook do
      accept [:path]

      argument :ebook, :map do
        allow_nil? false
      end

      change set_attribute(:type, :ebook)
      change NormalizePath
      change manage_relationship(:ebook, type: :create, authorize?: false)
    end

    create :create_audiobook do
      accept [:path]

      argument :audiobook, :map do
        allow_nil? false
      end

      change set_attribute(:type, :audiobook)
      change NormalizePath
      change manage_relationship(:audiobook, type: :create, authorize?: false)
    end
  end

  policies do
    policy actor_absent() do
      description "Media actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action(:read) do
      description "The Instance Administrator and system actor can read Media"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if actor_attribute_equals(:system?, true)
    end

    policy action([:destroy, :create_video, :create_ebook, :create_audiobook]) do
      description "Only the Instance Administrator can manage Media directly"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :path, :string do
      allow_nil? false
      public? true
    end

    attribute :type, MediaType do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    has_one :video, Video do
      destination_attribute :id
    end

    has_one :ebook, Ebook do
      destination_attribute :id
    end

    has_one :audiobook, Audiobook do
      destination_attribute :id
    end

    belongs_to :last_successful_media_import, ImportRun do
      allow_nil? true
      public? true
    end
  end

  identities do
    identity :unique_path, [:path]
  end
end
