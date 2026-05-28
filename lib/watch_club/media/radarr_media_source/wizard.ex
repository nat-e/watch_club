defmodule WatchClub.Media.RadarrMediaSource.Wizard do
  @moduledoc """
  In-memory state machine that backs the Add Radarr Source modal.

  Each step is an `update` action; transitioning through the state
  machine carries the user's progress without persisting anything.
  Once the final step validates, the LiveView hands the wizard's
  attributes to `Media.create_radarr_media_source/2`.

  States:

    * `:connection`     — capture base_url + api_key
    * `:request_profile` — pick quality profile + root folder
    * `:webhook`        — capture webhook callback URL
    * `:finished`       — all inputs validated; LiveView creates the MediaSource
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    extensions: [AshStateMachine]

  alias WatchClub.Media.MediaSource

  alias WatchClub.Media.RadarrMediaSource.Changes.{
    BackToPreviousStep,
    LoadRadarrProfiles,
    SeedFromMediaSource
  }

  alias WatchClub.Media.RadarrMediaSource.Validations.{
    CheckRadarrConnection,
    CheckRadarrWebhookUrl
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
      change set_attribute(:step, :connection)
    end

    create :for_edit do
      argument :media_source, :struct do
        allow_nil? false
        constraints instance_of: MediaSource
      end

      change SeedFromMediaSource
      change LoadRadarrProfiles
      change set_attribute(:step, :request_profile)
    end

    update :configure_connection do
      require_atomic? false
      accept [:base_url, :api_key]

      validate present(:base_url)
      validate present(:api_key)
      validate CheckRadarrConnection, only_when_valid?: true, before_action?: true

      change LoadRadarrProfiles
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
      validate CheckRadarrWebhookUrl, only_when_valid?: true, before_action?: true

      change transition_state(:finished)
    end

    update :back_to_previous_step do
      change BackToPreviousStep
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :base_url, :string do
      public? true
    end

    attribute :api_key, :string do
      public? true
      sensitive? true
    end

    # Loaded by `LoadRadarrProfiles` — display data, not user input.
    attribute :quality_profiles, {:array, :map} do
      default []
    end

    # Loaded by `LoadRadarrProfiles` — display data, not user input.
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
