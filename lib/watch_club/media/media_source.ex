defmodule WatchClub.Media.MediaSource do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Media.MediaSource.Calculations
  alias WatchClub.Media.{MediaImport, MediaSourceType, MediaType}
  alias WatchClub.Shared.Changes.NormalizePath

  postgres do
    table "media_sources"
    repo WatchClub.Repo
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub
    prefix "media_sources"

    publish :create_filesystem, ""
    publish :update, [[:id, nil]]
    publish :destroy, [[:id, nil]]
  end

  actions do
    defaults [:read]

    create :create_filesystem do
      primary? true
      accept [:media_type, :filesystem_path]

      change set_attribute(:source_type, :filesystem)
      change {NormalizePath, attribute: :filesystem_path}
    end

    update :update do
      primary? true
      accept [:filesystem_path]

      change {NormalizePath, attribute: :filesystem_path}
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    policy actor_absent() do
      description "Media Source actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action([:read, :create_filesystem, :update, :destroy]) do
      description "Only the Instance Administrator can manage Media Sources"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  preparations do
    prepare build(sort: [inserted_at: :desc])
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :source_type, MediaSourceType do
      allow_nil? false
      public? true
      default :filesystem
    end

    attribute :media_type, MediaType do
      allow_nil? false
      public? true
    end

    attribute :filesystem_path, :string do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :imports, MediaImport do
      destination_attribute :media_source_id
      public? true
      sort inserted_at: :desc
    end

    has_one :latest_import, MediaImport do
      destination_attribute :media_source_id
      sort inserted_at: :desc
      public? true
    end
  end

  calculations do
    calculate :name, :string, Calculations.Name do
      allow_nil? false
      public? true
    end
  end
end
