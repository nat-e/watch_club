defmodule WatchClub.Media.RadarrMediaSource do
  @moduledoc """
  Radarr-flavored configuration of a `MediaSource`.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Integrations.Radarr.Connection
  alias WatchClub.Media.MediaSource
  alias WatchClub.Media.RadarrMediaSource.Actions.LoadRadarrProfiles
  alias WatchClub.Shared.Changes.{NormalizePath, TrimUrl}

  postgres do
    table "radarr_media_sources"
    repo WatchClub.Repo

    references do
      reference :media_source, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :base_url,
        :api_key,
        :quality_profile_id,
        :quality_profile_name,
        :root_folder_path,
        :local_root_folder_path
      ]

      change {TrimUrl, attribute: :base_url}
      change {NormalizePath, attribute: :local_root_folder_path}
    end

    update :update do
      primary? true

      accept [
        :base_url,
        :api_key,
        :quality_profile_id,
        :quality_profile_name,
        :root_folder_path,
        :local_root_folder_path
      ]

      change {TrimUrl, attribute: :base_url}
      change {NormalizePath, attribute: :local_root_folder_path}
    end

    action :load_radarr_profiles, :struct do
      description """
      Talks to a Radarr server and returns its quality profiles + root
      folders.
      """

      constraints instance_of: Connection

      argument :base_url, :string, allow_nil?: false
      argument :api_key, :string, allow_nil?: false

      run LoadRadarrProfiles
    end
  end

  policies do
    policy actor_absent() do
      description "RadarrMediaSource actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action(:read) do
      description "Instance Administrator and the system actor can read RadarrMediaSource"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if WatchClub.Checks.IsSystemActor
    end

    policy action([:create, :update, :destroy, :load_radarr_profiles]) do
      description "Only the Instance Administrator can write RadarrMediaSource directly"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub
    prefix "media_sources"

    publish :update, [[:id, nil]]
  end

  attributes do
    attribute :id, :uuid_v7 do
      primary_key? true
      allow_nil? false
    end

    attribute :base_url, :string do
      allow_nil? false
      public? true
    end

    attribute :api_key, :string do
      allow_nil? false
      public? true
      sensitive? true
    end

    attribute :quality_profile_id, :integer do
      allow_nil? false
      public? true
    end

    attribute :quality_profile_name, :string do
      allow_nil? false
      public? true
    end

    attribute :root_folder_path, :string do
      allow_nil? false
      public? true
    end

    # Optional path mapping. Nil means "Radarr's root folder is accessible
    # at the same path on Watch Club's host as it is to Radarr".
    attribute :local_root_folder_path, :string do
      allow_nil? true
      public? true
    end
  end

  relationships do
    belongs_to :media_source, MediaSource do
      primary_key? true
      allow_nil? false
      define_attribute? false
      source_attribute :id
    end
  end
end
