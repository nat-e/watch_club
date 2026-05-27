defmodule WatchClub.Media.MediaImport do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshOban, AshStateMachine]

  import Ash.Expr

  alias WatchClub.Media.MediaImport.Changes
  alias WatchClub.Media.MediaSource

  postgres do
    table "media_imports"
    repo WatchClub.Repo

    references do
      reference :media_source, on_delete: :delete, on_update: :update
    end

    custom_indexes do
      index [:media_source_id],
        unique: true,
        name: "media_imports_one_processing_per_media_source_index",
        where: "status = 'processing'"
    end
  end

  oban do
    triggers do
      trigger :run do
        action :run
        where expr(status == :processing)
        queue :media_imports
        max_attempts 1
        on_error :fail
        scheduler_cron false
        worker_module_name WatchClub.Media.Workers.ExecuteMediaImport
      end
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

    update :run do
      require_atomic? false
      accept []

      change Changes.Execute
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
      change Changes.CancelObanJob
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

    policy action([:run, :complete, :fail]) do
      description "Only the system actor can process Media Imports in the background"
      authorize_if WatchClub.Checks.IsSystemActor
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub
    prefix "media_imports"

    publish :start, [[:media_source_id, nil]]
    publish :complete, [[:media_source_id, nil]]
    publish :fail, [[:media_source_id, nil]]
    publish :cancel, [[:media_source_id, nil]]
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
    belongs_to :media_source, MediaSource do
      allow_nil? false
      public? true
    end
  end
end
