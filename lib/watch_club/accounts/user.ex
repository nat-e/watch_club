defmodule WatchClub.Accounts.User do
  require Ash.Query

  alias WatchClub.Accounts.{UserLocale, UserSettings}
  alias WatchClub.Clubs.{Club, Membership}

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  use Gettext, backend: WatchClubWeb.Gettext

  postgres do
    table "users"
    repo(WatchClub.Repo)

    identity_wheres_to_sql(only_one_administrator: "is_administrator = true")
  end

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    tokens do
      enabled? true
      token_resource WatchClub.Accounts.Token
      signing_secret WatchClub.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :username
        hash_provider AshAuthentication.BcryptProvider
      end

      remember_me :remember_me
    end
  end

  actions do
    defaults [:read]

    create :create_administrator do
      description "Creates the administrator for this instance."
      accept [:username]

      argument :locale, UserLocale do
        allow_nil? false
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # validates that the password matches the confirmation
      validate {AshAuthentication.Strategy.Password.PasswordConfirmationValidation,
                strategy_name: :password}

      change set_attribute(:administrator?, true)

      # Hashes the provided password
      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}

      # Generates an authentication token for the user
      change {AshAuthentication.GenerateTokenChange, strategy_name: :password}

      change manage_relationship(:locale, :settings,
               type: :create,
               value_is_key: :locale,
               authorize?: false
             )

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :get_administrator do
      description "Returns the administrator user, or nil if it was not setup yet"
      get? true

      filter expr(administrator? == true)
    end

    action :administrator_exists?, :boolean do
      description "Returns whether or not the administrator account has been setup"

      run fn _input, _ ->
        __MODULE__ |> Ash.Query.filter(administrator? == true) |> Ash.exists(authorize?: false)
      end
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject

      # Load the club memberships when loading the logged in user
      prepare build(
                load: [:settings, memberships: [:club]],
                context: %{private: %{authorize?: false}}
              )
    end

    read :get_current_user do
      description "Gets the user and relationships corresponding to the actor"
      get? true
      filter expr(id == ^actor(:id))

      # Load the club memberships when loading the logged in user
      prepare build(load: [:settings, memberships: [:club]])
    end

    update :change_password do
      # Use this action to allow users to change their password by providing
      # their current password and a new password.

      require_atomic? false
      accept []
      argument :current_password, :string, sensitive?: true, allow_nil?: false

      argument :password, :string,
        sensitive?: true,
        allow_nil?: false,
        constraints: [min_length: 8]

      argument :password_confirmation, :string, sensitive?: true, allow_nil?: false

      validate confirm(:password, :password_confirmation)

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password}

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    read :sign_in_with_password do
      description "Attempt to sign in using a username and password."
      get? true

      argument :username, :string do
        description "The username to use for retrieving the user."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching user."
        allow_nil? false
        sensitive? true
      end

      argument :invitation_id, :uuid_v7 do
        description "An invitation to accept upon signing in."
        allow_nil? true
      end

      validate present(:username) do
        message dgettext_noop("errors", "Username is required")
      end

      validate present(:password) do
        message dgettext_noop("errors", "Password is required")
      end

      # validates the provided username and password and generates a token
      prepare AshAuthentication.Strategy.Password.SignInPreparation

      prepare WatchClub.Accounts.Preparations.AcceptInvitation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_token do
      # In the generated sign in components, we validate the
      # username and password directly in the LiveView
      # and generate a short-lived token that can be used to sign in over
      # a standard controller action, exchanging it for a standard token.
      # This action performs that exchange. If you do not use the generated
      # liveviews, you may remove this action, and set
      # `sign_in_tokens_enabled? false` in the password strategy.

      description "Attempt to sign in using a short-lived sign in token."
      get? true

      argument :token, :string do
        description "The short-lived sign in token."
        allow_nil? false
        sensitive? true
      end

      # validates the provided sign in token and generates a token
      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :register_with_password do
      description "Register a new user with a username and password."
      accept [:username]

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      argument :invitation_id, :uuid_v7 do
        description "An invitation to accept upon signing up."
        allow_nil? false
      end

      argument :locale, UserLocale do
        allow_nil? false
      end

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      # If there is an invitation, accept it in after_action hook
      change WatchClub.Accounts.Changes.AcceptInvitation

      change manage_relationship(:locale, :settings,
               type: :create,
               value_is_key: :locale,
               authorize?: false
             )

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    action :request_password_reset_token do
      description "Send password reset instructions to a user if they exist."

      argument :username, :string do
        allow_nil? false
      end

      # creates a reset token and invokes the relevant senders
      run {AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_username}
    end

    read :get_by_username do
      description "Looks up a user by their username"
      get_by :username
    end

    update :reset_password_with_token do
      argument :reset_token, :string do
        allow_nil? false
        sensitive? true
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # validates the provided reset token
      validate AshAuthentication.Strategy.Password.ResetTokenValidation

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    # Everyone can register and signin
    policy action([:sign_in_with_password, :register_with_password]) do
      authorize_if always()
    end

    policy action(:get_administrator) do
      authorize_if actor_attribute_equals(:administrator?, true)
    end

    policy action([:administrator_exists?, :create_administrator, :user_exists?]) do
      authorize_if always()
    end

    policy action(:get_current_user) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:read) do
      authorize_if always()
    end
  end

  validations do
    validate present(:username) do
      message dgettext_noop("errors", "The username is required")
    end

    validate string_length(:username, min: 3) do
      message dgettext_noop("errors", "Username must be at least %{min} characters")
    end

    validate string_length(:username, max: 30) do
      message dgettext_noop("errors", "Username cannot be longer than %{max} characters")
    end

    validate match(:username, ~r/^[a-z0-9_]+$/) do
      message dgettext_noop(
                "errors",
                "Username can only contain lower case letters, numbers and _"
              )
    end

    validate present(:password) do
      message dgettext_noop("errors", "The password is required")
    end

    validate string_length(:password, min: 8) do
      message dgettext_noop("errors", "Password cannot be longer than %{max} characters")
    end

    validate confirm(:password, :password_confirmation) do
      message dgettext_noop("errors", "Passwords do not match")
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :username, :string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :confirmed_at, :utc_datetime_usec

    attribute :administrator?, :boolean,
      allow_nil?: false,
      default: false,
      source: :is_administrator
  end

  relationships do
    has_many :memberships, Membership
    many_to_many :clubs, Club, through: Membership
    has_one :settings, UserSettings
  end

  identities do
    identity :unique_username, [:username]

    identity :only_one_administrator, [:administrator?] do
      where expr(administrator? == true)
      message dgettext_noop("errors", "An administrator already exists")
    end
  end
end
