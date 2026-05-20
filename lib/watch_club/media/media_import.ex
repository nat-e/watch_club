defmodule WatchClub.Media.MediaImport do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  alias WatchClub.Media.Changes.SnapshotMediaImportConfiguration

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
  end

  state_machine do
    initial_states [:pending]
    default_initial_state :pending
    state_attribute :status

    transitions do
      transition :start, from: :pending, to: :running
      transition :complete, from: :running, to: :completed
      transition :fail, from: [:pending, :running], to: :failed
    end
  end

  actions do
    defaults [:read]

    create :trigger_manually do
      primary? true
      accept [:configuration_id, :refresh_metadata?]

      change set_attribute(:triggered_manually?, true)
      change SnapshotMediaImportConfiguration
    end

    update :start do
      accept []

      change transition_state(:running)
    end

    update :complete do
      accept []

      change transition_state(:completed)
    end

    update :fail do
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

    policy action([:read, :trigger_manually, :start, :complete, :fail]) do
      description "Only the Instance Administrator can inspect and manage Media Imports"
      authorize_if actor_attribute_equals(:administrator?, true)
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
