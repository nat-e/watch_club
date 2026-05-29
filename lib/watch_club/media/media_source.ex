defmodule WatchClub.Media.MediaSource do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  import Ash.Expr

  alias WatchClub.Media.ServarrFlavor

  alias WatchClub.Media.{
    FilesystemMediaSource,
    MediaImport,
    MediaSourceType,
    MediaType,
    ServarrMediaSource
  }

  alias WatchClub.Media.MediaSource.Calculations.GetImplementation

  alias WatchClub.Media.MediaSource.Changes.{
    ComputeName,
    ManageServarrImplementation,
    SetServarrTypes
  }

  alias WatchClub.Shared.Changes.NormalizePath

  postgres do
    table "media_sources"
    repo WatchClub.Repo
  end

  actions do
    defaults [:read]

    create :create_filesystem do
      primary? true

      argument :filesystem_path, :string, allow_nil?: false

      accept [:media_type]

      change set_attribute(:source_type, :filesystem)
      change {NormalizePath, argument: :filesystem_path}

      change manage_relationship(:filesystem_path, :filesystem,
               type: :direct_control,
               value_is_key: :filesystem_path
             )

      change ComputeName
      change load([:implementation, :can_request?])
    end

    # One action for both Servarr flavors. `flavor` drives `source_type`
    # and `media_type`; the `create_radarr` / `create_sonarr` code
    # interfaces on the domain pin it so callers stay product-specific.
    create :create_servarr do
      argument :flavor, ServarrFlavor, allow_nil?: false
      argument :base_url, :string, allow_nil?: false
      argument :api_key, :string, allow_nil?: false
      argument :quality_profile_id, :integer, allow_nil?: false
      argument :quality_profile_name, :string, allow_nil?: false
      argument :root_folder_path, :string, allow_nil?: false
      argument :local_root_folder_path, :string, allow_nil?: true
      argument :webhook_callback_base_url, :string, allow_nil?: false

      change SetServarrTypes
      change {NormalizePath, argument: :local_root_folder_path}
      change ManageServarrImplementation
      change ComputeName
      change load([:implementation, :can_request?])
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

    policy action(:read) do
      description "Instance Administrator and the system actor can read Media Sources"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if WatchClub.Checks.IsSystemActor
    end

    policy action([:create_filesystem, :create_servarr, :destroy]) do
      description "Only the Instance Administrator can manage Media Sources"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub
    prefix "media_sources"

    publish_all :create, ""
    publish_all :update, [[:id, nil]]
    publish_all :destroy, [[:id, nil]]
  end

  preparations do
    prepare build(sort: [inserted_at: :desc], load: [:implementation, :can_request?])
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :source_type, MediaSourceType do
      allow_nil? false
      public? true
      default :filesystem
    end

    attribute :media_type, MediaType do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    has_one :filesystem, FilesystemMediaSource do
      destination_attribute :id
      public? true
    end

    has_one :servarr, ServarrMediaSource do
      destination_attribute :id
      public? true
    end

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
    calculate :implementation,
              :union,
              GetImplementation do
      constraints types: [
                    filesystem: [type: :struct, constraints: [instance_of: FilesystemMediaSource]],
                    servarr: [type: :struct, constraints: [instance_of: ServarrMediaSource]]
                  ]

      public? true
      allow_nil? false
    end

    # Kept in sync with `MediaSourceType` — request-capable types are
    # `:radarr` and `:sonarr` (and, future, `:chaptarr`).
    calculate :can_request?,
              :boolean,
              expr(source_type in [:radarr, :sonarr]) do
      public? true
    end
  end
end
