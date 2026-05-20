defmodule WatchClub.Media.MediaImportResult do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Media.Changes.NormalizePath
  alias WatchClub.Media.{MediaImport, MediaImportResultStatus}

  import Ash.Expr

  postgres do
    table "media_import_results"
    repo(WatchClub.Repo)

    references do
      reference(:media_import, on_delete: :delete, on_update: :update)
    end
  end

  actions do
    defaults [:read]

    read :by_media_import do
      argument :media_import_id, :uuid_v7, allow_nil?: false

      filter expr(media_import_id == ^arg(:media_import_id))
    end

    create :create do
      primary? true
      accept [:media_import_id, :status, :path, :media_id, :message, :metadata]

      change {NormalizePath, attribute: :path}
    end
  end

  policies do
    policy actor_absent() do
      description "Media Import Result actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action([:read, :by_media_import]) do
      description "Only the Instance Administrator can inspect Media Import Results"
      authorize_if actor_attribute_equals(:administrator?, true)
    end

    policy action(:create) do
      description "The Instance Administrator and system actor can create Media Import Results"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if actor_attribute_equals(:system?, true)
    end
  end

  preparations do
    prepare build(sort: [media_import_id: :desc, inserted_at: :desc])
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :status, MediaImportResultStatus do
      allow_nil? false
      public? true
    end

    attribute :path, :string do
      allow_nil? false
      public? true
    end

    attribute :media_id, :uuid_v7 do
      allow_nil? true
      public? true
    end

    attribute :message, :string do
      allow_nil? true
      public? true
    end

    attribute :metadata, :map do
      allow_nil? false
      default %{}
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :media_import, MediaImport do
      allow_nil? false
      public? true
    end
  end
end
