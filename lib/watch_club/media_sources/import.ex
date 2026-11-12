defmodule WatchClub.MediaSources.Import do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.MediaSources,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshStateMachine]

  use Gettext, backend: WatchClubWeb.Gettext

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
        where: "status = 'processing'",
        message: dgettext_noop("errors", "An import of this media source is already running.")
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
      accept [:media_source_id, :files_to_process, :regenerate_thumbnails_and_markers?]

      change set_attribute(:triggered_manually?, true)
      change Changes.Schedule
    end

    update :complete do
      accept []

      change set_attribute(:finished_at, &DateTime.utc_now/0)
      change transition_state(:completed)
    end

    update :fail do
      accept [:failed_file_count]

      change set_attribute(:finished_at, &DateTime.utc_now/0)
      change transition_state(:failed)
    end

    update :finish_scan do
      description "Records how many files the scan found to process"
      accept [:file_count]
    end

    # Concurrent ingest jobs count their files, so the counts add up in the database
    update :count_file do
      description "Counts a file the Media Import processed, by its outcome"
      accept []

      argument :outcome, :atom do
        allow_nil? false
        constraints one_of: [:matched, :unmatched, :unreadable]
      end

      change atomic_update(
               :matched_file_count,
               expr(matched_file_count + if(^arg(:outcome) == :matched, do: 1, else: 0))
             )

      change atomic_update(
               :unmatched_file_count,
               expr(unmatched_file_count + if(^arg(:outcome) == :unmatched, do: 1, else: 0))
             )

      change atomic_update(
               :unreadable_file_count,
               expr(unreadable_file_count + if(^arg(:outcome) == :unreadable, do: 1, else: 0))
             )
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

    policy action([:complete, :fail, :finish_scan, :count_file]) do
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

    attribute :files_to_process, WatchClub.MediaSources.FilesToProcess do
      allow_nil? false
      default :new
      public? true
    end

    # New files get theirs anyway, so it only matters with New and unmatched files or All files
    attribute :regenerate_thumbnails_and_markers?, :boolean do
      description "Rebuilds the Scrubbing Thumbnails and Markers of every Video it processes"
      allow_nil? false
      default false
      public? true
      source :regenerate_thumbnails_and_markers
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

    attribute :file_count, :integer do
      description "The files the scan found to process, nil until it finishes"
      public? true
    end

    attribute :matched_file_count, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :unmatched_file_count, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :unreadable_file_count, :integer do
      description "Files ffprobe couldn't read, which got no Media"
      allow_nil? false
      default 0
      public? true
    end

    attribute :failed_file_count, :integer do
      description "Files whose ingest job crashed on its last attempt"
      allow_nil? false
      default 0
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
