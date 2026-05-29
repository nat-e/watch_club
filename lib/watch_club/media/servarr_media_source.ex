defmodule WatchClub.Media.ServarrMediaSource do
  @moduledoc """
  Servarr-flavored configuration of a `MediaSource`. Backs both Radarr and
  Sonarr sources; the `flavor` attribute selects which, and drives the
  integration calls (app name, endpoints, webhook event flags).
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Media.ServarrFlavor, as: Flavor
  alias WatchClub.Media.MediaSource

  alias WatchClub.Media.ServarrMediaSource.Changes.{
    GenerateWebhookSecret,
    RegisterServarrWebhook,
    ScheduleWebhookDeletion,
    UpdateServarrWebhook
  }

  alias WatchClub.Shared.Changes.{NormalizePath, TrimUrl}

  postgres do
    table "servarr_media_sources"
    repo WatchClub.Repo

    references do
      reference :media_source, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :flavor,
        :base_url,
        :api_key,
        :quality_profile_id,
        :quality_profile_name,
        :root_folder_path,
        :local_root_folder_path,
        :webhook_callback_base_url
      ]

      change {TrimUrl, attribute: :base_url}
      change {TrimUrl, attribute: :webhook_callback_base_url}
      change {NormalizePath, attribute: :local_root_folder_path}
      change GenerateWebhookSecret
      change RegisterServarrWebhook
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :base_url,
        :api_key,
        :quality_profile_id,
        :quality_profile_name,
        :root_folder_path,
        :local_root_folder_path,
        :webhook_callback_base_url
      ]

      change {TrimUrl, attribute: :base_url}
      change {TrimUrl, attribute: :webhook_callback_base_url}
      change {NormalizePath, attribute: :local_root_folder_path}
      change UpdateServarrWebhook
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      change ScheduleWebhookDeletion
    end
  end

  policies do
    policy actor_absent() do
      description "ServarrMediaSource actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action(:read) do
      description "Instance Administrator and the system actor can read ServarrMediaSource"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if WatchClub.Checks.IsSystemActor
    end

    policy action([:create, :update, :destroy]) do
      description "Only the Instance Administrator can write ServarrMediaSource directly"
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

    # Which Servarr product this source talks to.
    attribute :flavor, Flavor do
      allow_nil? false
      public? true
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

    # Optional path mapping. Nil means "the server's root folder is
    # accessible at the same path on Watch Club's host as it is to the
    # server".
    attribute :local_root_folder_path, :string do
      allow_nil? true
      public? true
    end

    # The base URL the server will use to reach WatchClub. Stored
    # per-source because the server can sit on a different network
    # (Docker, LAN, remote) than the WatchClub host itself.
    attribute :webhook_callback_base_url, :string do
      allow_nil? false
      public? true
    end

    # Shared secret WatchClub sends to itself in the `X-WatchClub-Token`
    # header on every non-Test event, generated at create time and never
    # exposed back to the form.
    attribute :webhook_secret, :string do
      allow_nil? false
      public? false
      sensitive? true
    end

    # The id the server assigned to the registered Webhook notification.
    # Carried into the destroy job's args so the cleanup call survives the
    # row being gone.
    attribute :notification_id, :integer do
      allow_nil? false
      public? false
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
