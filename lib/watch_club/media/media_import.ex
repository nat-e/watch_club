defmodule WatchClub.Media.MediaImport do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshOban, AshStateMachine]

  import Ash.Expr

  alias WatchClub.Media.Changes.{
    EnqueueMediaImportProcess,
    ProcessMediaImport,
    SnapshotMediaImportConfiguration
  }

  alias WatchClub.Media.{
    MediaImportConfiguration,
    MediaImportResult
  }

  postgres do
    table "media_imports"
    repo(WatchClub.Repo)

    references do
      reference(:configuration, on_delete: :nilify, on_update: :update)
    end

    custom_indexes do
      index([:configuration_id],
        unique: true,
        name: "media_imports_one_processing_per_configuration_index",
        where: "status = 'processing' AND configuration_id IS NOT NULL"
      )
    end
  end

  oban do
    triggers do
      trigger :process do
        action :process

        where expr(
                status == :pending and
                  not exists(
                    WatchClub.Media.MediaImport,
                    configuration_id == parent(configuration_id) and status == :processing
                  )
              )

        queue(:media_imports)
        max_attempts(1)
        on_error(:mark_failed)
        scheduler_cron(false)
        worker_module_name(WatchClub.Media.Workers.ProcessMediaImport)
      end
    end
  end

  state_machine do
    initial_states [:pending]
    default_initial_state :pending
    state_attribute :status

    transitions do
      transition :process, from: :pending, to: :processing
      transition :mark_completed, from: :processing, to: :completed
      transition :mark_failed, from: [:pending, :processing], to: :failed
    end
  end

  actions do
    defaults [:read]

    create :trigger_manually do
      primary? true
      accept [:configuration_id, :refresh_metadata?]

      change set_attribute(:triggered_manually?, true)
      change SnapshotMediaImportConfiguration
      change EnqueueMediaImportProcess
    end

    update :process do
      require_atomic? false
      accept []

      change transition_state(:processing)
      change ProcessMediaImport
    end

    update :mark_completed do
      accept []

      change transition_state(:completed)
    end

    update :mark_failed do
      accept []

      change transition_state(:failed)
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
      authorize_if actor_attribute_equals(:system?, true)
    end

    policy action(:trigger_manually) do
      description "Only the Instance Administrator can manually trigger Media Imports"
      authorize_if actor_attribute_equals(:administrator?, true)
    end

    policy action([:process, :mark_completed, :mark_failed]) do
      description "Only the system actor can process Media Imports in the background"
      authorize_if actor_attribute_equals(:system?, true)
    end
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

    attribute :configuration_snapshot, :map do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :configuration, MediaImportConfiguration do
      allow_nil? true
      public? true
    end

    has_many :results, MediaImportResult do
      public? true
      sort media_import_id: :desc, inserted_at: :desc
    end
  end
end
