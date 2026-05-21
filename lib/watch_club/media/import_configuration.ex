defmodule WatchClub.Media.ImportConfiguration do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Contents.ContentType
  alias WatchClub.Media.ImportConfiguration.Calculations
  alias WatchClub.Media.ImportConfiguration.Validations
  alias WatchClub.Media.{ImportRun, ImportSourceType, MediaType}
  alias WatchClub.Shared.Changes.NormalizePath

  postgres do
    table "media_import_configurations"
    repo WatchClub.Repo

    check_constraints do
      check_constraint [:content_type, :media_type],
        name: "media_import_configurations_valid_content_media_type_check",
        check: """
        (content_type = 'movie' AND media_type = 'video') OR
        (content_type = 'tv_show' AND media_type = 'video') OR
        (content_type = 'book' AND media_type IN ('ebook', 'audiobook'))
        """,
        message: "Media Import Configuration content type and media type are incompatible"
    end
  end

  actions do
    defaults [:read]

    create :create_filesystem do
      primary? true
      accept [:content_type, :media_type, :filesystem_path]

      validate Validations.ValidCombination

      change set_attribute(:source_type, :filesystem)
      change {NormalizePath, attribute: :filesystem_path}
    end

    update :update do
      primary? true
      accept [:filesystem_path]

      change {NormalizePath, attribute: :filesystem_path}
    end

    update :disable do
      change set_attribute(:disabled?, true)
    end

    update :enable do
      change set_attribute(:disabled?, false)
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    policy actor_absent() do
      description "Media Import Configuration actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action([:read, :create_filesystem, :update, :disable, :enable, :destroy]) do
      description "Only the Instance Administrator can manage Media Import Configurations"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  preparations do
    prepare build(sort: [inserted_at: :desc])
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :source_type, ImportSourceType do
      allow_nil? false
      public? true
      default :filesystem
    end

    attribute :content_type, ContentType do
      allow_nil? false
      public? true
    end

    attribute :media_type, MediaType do
      allow_nil? false
      public? true
    end

    attribute :filesystem_path, :string do
      allow_nil? false
      public? true
    end

    attribute :disabled?, :boolean do
      allow_nil? false
      default false
      public? true
      source :is_disabled
    end

    timestamps()
  end

  relationships do
    has_many :imports, ImportRun do
      destination_attribute :configuration_id
      public? true
      sort inserted_at: :desc
    end
  end

  calculations do
    calculate :name, :string, Calculations.Name do
      allow_nil? false
      public? true
    end
  end
end
