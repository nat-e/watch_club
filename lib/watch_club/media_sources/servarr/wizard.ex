defmodule WatchClub.MediaSources.Servarr.Wizard do
  @moduledoc """
  In-memory state machine that backs the Add Servarr Source modal (Radarr
  and Sonarr).

  Each step is an `update` action; transitioning through the state machine
  carries the user's progress without persisting anything. Once the final
  step validates, the LiveView hands the wizard's attributes to
  `Media.create_servarr_media_source/2`.

  States:

    * `:connection`      — capture base_url + api_key
    * `:request_profile` — pick quality profile + root folder
    * `:webhook`         — capture webhook callback URL
    * `:finished`        — all inputs validated; LiveView creates the Source
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.MediaSources,
    extensions: [AshStateMachine]

  alias WatchClub.MediaSources.Servarr.Flavor
  alias WatchClub.MediaSources.Source

  alias WatchClub.MediaSources.Servarr.Changes.{
    BackToPreviousStep,
    LoadProfiles,
    SeedFromSource
  }

  alias WatchClub.MediaSources.Servarr.Validations.{
    CheckConnection,
    CheckWebhookUrl
  }

  state_machine do
    initial_states [:connection, :request_profile]
    default_initial_state :connection
    state_attribute :step

    transitions do
      transition :configure_connection, from: :connection, to: :request_profile

      transition :configure_request_profile,
        from: :request_profile,
        to: :webhook

      transition :configure_webhook, from: :webhook, to: :finished

      transition :back_to_previous_step,
        from: [:request_profile, :webhook],
        to: [:connection, :request_profile]
    end
  end

  actions do
    create :for_create do
      argument :flavor, Flavor, allow_nil?: false

      change set_attribute(:flavor, arg(:flavor))
      change set_attribute(:step, :connection)
    end

    create :for_edit do
      argument :media_source, :struct do
        allow_nil? false
        constraints instance_of: Source
      end

      change SeedFromSource
      change LoadProfiles
      change set_attribute(:step, :request_profile)
    end

    update :configure_connection do
      require_atomic? false
      accept [:base_url, :api_key]

      validate present(:base_url)
      validate present(:api_key)
      validate CheckConnection, only_when_valid?: true, before_action?: true

      change LoadProfiles
      change transition_state(:request_profile)
    end

    update :configure_request_profile do
      require_atomic? false
      accept [:selected_root_path, :selected_quality_profile_id, :local_root_folder_path]

      validate present(:selected_quality_profile_id)
      validate present(:selected_root_path)

      change transition_state(:webhook)
    end

    update :configure_webhook do
      require_atomic? false
      accept [:webhook_callback_base_url]

      validate present(:webhook_callback_base_url)
      validate CheckWebhookUrl, only_when_valid?: true, before_action?: true

      change transition_state(:finished)
    end

    update :back_to_previous_step do
      change BackToPreviousStep
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :flavor, Flavor do
      public? true
    end

    attribute :base_url, :string do
      public? true
    end

    attribute :api_key, :string do
      public? true
      sensitive? true
    end

    # Loaded by `LoadProfiles` — display data, not user input.
    attribute :quality_profiles, {:array, :map} do
      default []
    end

    # Loaded by `LoadProfiles` — display data, not user input.
    attribute :root_folders, {:array, :string} do
      default []
    end

    attribute :selected_quality_profile_id, :integer do
      public? true
    end

    attribute :selected_root_path, :string do
      public? true
    end

    attribute :webhook_callback_base_url, :string do
      public? true
    end

    attribute :local_root_folder_path, :string do
      public? true
    end
  end
end
