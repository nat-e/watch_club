defmodule WatchClub.MediaSources.Import do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.MediaSources,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshStateMachine]

  alias WatchClub.MediaSources.Import.Changes
  alias WatchClub.MediaSources.Source

  postgres do
    table "media_imports"
    repo WatchClub.Repo

    references do
      reference :media_source, on_delete: :delete, index?: true
    end

    custom_indexes do
      index [:media_source_id],
        unique: true,
        name: "media_imports_one_processing_per_media_source_index",
        where: "status = 'processing'"
    end
  end

  state_machine do
    initial_states [:processing]
    default_initial_state :processing
    state_attribute :status

    transitions do
      transition :complete, from: :processing, to: :completed
      transition :fail, from: :processing, to: :failed
      transition :cancel, from: :processing, to: :cancelled
    end
  end

  actions do
    defaults [:read]

    create :start do
      primary? true
      accept [:media_source_id, :refresh_metadata?]

      change set_attribute(:triggered_manually?, true)
      change Changes.Schedule
    end

    update :complete do
      accept []

      change set_attribute(:finished_at, &DateTime.utc_now/0)
      change transition_state(:completed)
    end

    update :fail do
      accept []

      change set_attribute(:finished_at, &DateTime.utc_now/0)
      change transition_state(:failed)
    end

    update :cancel do
      require_atomic? false
      accept []

      change set_attribute(:finished_at, &DateTime.utc_now/0)
      change transition_state(:cancelled)
      change Changes.CancelObanJobs
    end
  end

  policies do
    policy actor_absent() do
      description "Media Import actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action(:read) do
      description "The Instance Administrator and system actor can inspect Media Imports"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if WatchClub.Checks.IsSystemActor
    end

    policy action([:start, :cancel]) do
      description "Only the Instance Administrator can manage Media Imports"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if WatchClub.Checks.IsSystemActor
    end

    policy action([:complete, :fail]) do
      description "Only the system actor can process Media Imports in the background"
      authorize_if WatchClub.Checks.IsSystemActor
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    publish_all :create, ["media_sources", "admin"]
    publish_all :update, ["media_sources", "admin"]
  end

  preparations do
    prepare build(sort: [inserted_at: :desc])
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :refresh_metadata?, :boolean do
      allow_nil? false
      default false
      public? true
      source :refresh_metadata
    end

    attribute :triggered_manually?, :boolean do
      allow_nil? false
      default true
      public? true
      source :is_triggered_manually
    end

    attribute :finished_at, :utc_datetime_usec do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :media_source, Source do
      allow_nil? false
      public? true
    end
  end
end
