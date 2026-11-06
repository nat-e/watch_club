defmodule WatchClub.Accounts.User do
  require Ash.Query

  alias WatchClub.Accounts.{UserLocale, UserSettings}
  alias WatchClub.Clubs.{Club, Membership}
  alias WatchClub.Conversations.Participant
  alias WatchClub.Lists.ContentList

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication],
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  postgres do
    table "users"
    repo WatchClub.Repo

    identity_wheres_to_sql only_one_administrator: "is_administrator = true"
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

        # Password confirmation is enforced by the resource-level `confirm`
        # validation, which owns the localized message
        confirmation_required? false

        resettable do
          password_reset_action_name :reset_password_with_token
          # Reset links are handed out manually by the administrator, there is nothing to send
          sender fn _user, _token, _opts -> :ok end
        end
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

    action :administrator_exists?, :boolean do
      description "Returns whether or not the administrator account has been setup"

      run fn _input, _ ->
        __MODULE__
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> Ash.Query.filter(administrator? == true)
        |> Ash.exists()
      end
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject

      # Load what the navigation shows when loading the logged in user
      prepare build(
                load: [
                  :settings,
                  :lists,
                  :unread_conversation_count,
                  memberships: [club: [:libraries]]
                ],
                context: %{private: %{authorize?: false}}
              )
    end

    read :get_current_user do
      description "Gets the user and relationships corresponding to the actor"
      get? true
      filter expr(id == ^actor(:id))

      # Load what the navigation shows when loading the logged in user
      prepare build(
                load: [
                  :settings,
                  :lists,
                  :unread_conversation_count,
                  memberships: [club: [:libraries]]
                ]
              )
    end

    update :change_password do
      # Use this action to allow users to change their password by providing
      # their current password and a new password.

      # Password validation checks the current password against the stored hash,
      # which cannot be expressed as a database-atomic update.
      require_atomic? false
      accept []
      argument :current_password, :string, sensitive?: true, allow_nil?: false

      argument :password, :string,
        sensitive?: true,
        allow_nil?: false

      argument :password_confirmation, :string, sensitive?: true, allow_nil?: false

      validate present(:current_password) do
        message dgettext_noop("errors", "Your current password is required")
      end

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password} do
        message dgettext_noop("errors", "Your current password is invalid")
      end

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}

      # Generates an authentication token so the current session can be
      # re-established after the password change revokes all tokens
      change {AshAuthentication.GenerateTokenChange, strategy_name: :password}

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
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

      validate present(:username) do
        message dgettext_noop("errors", "Username is required")
      end

      validate present(:password) do
        message dgettext_noop("errors", "Password is required")
      end

      # validates the provided username and password and generates a token
      prepare AshAuthentication.Strategy.Password.SignInPreparation

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
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      argument :invitation_code, :string do
        description "An invitation code to accept upon signing up."
        allow_nil? false
      end

      argument :locale, UserLocale do
        allow_nil? false
      end

      validate present(:invitation_code) do
        message dgettext_noop("errors", "The invitation code is required")
      end

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange

      # Validates the invitation code and creates one club member membership per granted club
      change WatchClub.Accounts.Changes.ApplyInvitationCode

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

    action :generate_password_reset_token, :string do
      description "Generates a password reset token for a user. The administrator sends the reset link to the user manually."

      argument :user_id, :uuid do
        allow_nil? false
      end

      run fn input, context ->
        user = Ash.get!(__MODULE__, input.arguments.user_id, Ash.Context.to_opts(context))
        strategy = AshAuthentication.Info.strategy!(__MODULE__, :password)

        {:ok, _token} = AshAuthentication.Strategy.Password.reset_token_for(strategy, user)
      end
    end

    destroy :destroy do
      description "Deletes a user account. The Library items they created will remain."

      # Delete memberships through the action (not the DB cascade) so the
      # membership PubSub notifications are sent
      change cascade_destroy(:memberships, return_notifications?: true, after_action?: false)
    end

    update :reset_password_with_token do
      # Password hashing and token validation cannot be expressed as a
      # database-atomic update
      require_atomic? false

      argument :reset_token, :string do
        allow_nil? false
        sensitive? true
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

      # validates the provided reset token
      validate AshAuthentication.Strategy.Password.ResetTokenValidation do
        message dgettext_noop("errors", "This password reset link is invalid or has expired")
      end

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
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

    # Possession of a valid reset token is the credential, the action validates it
    policy action(:reset_password_with_token) do
      authorize_if always()
    end

    # Users can change their own password by providing their current one
    policy action(:change_password) do
      authorize_if expr(id == ^actor(:id))
    end

    # Only the instance administrator can create password reset links
    policy action(:generate_password_reset_token) do
      authorize_if actor_attribute_equals(:administrator?, true)
    end

    policy action([:administrator_exists?, :create_administrator]) do
      authorize_if always()
    end

    policy action(:get_current_user) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:read) do
      authorize_if always()
    end

    # Only the instance administrator can delete users, and the
    # administrator account itself can never be deleted
    policy action(:destroy) do
      forbid_if expr(administrator? == true)
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    publish_all :create, ["users", "admin"]
    publish_all :destroy, ["users", "admin"]
  end

  changes do
    # Give every newly created user a default, localized "To Watch" list
    change WatchClub.Accounts.Changes.CreateToWatchList, on: [:create]
  end

  validations do
    # Customer-facing validations own localized messages for form errors.
    # Keep shape rules here instead of duplicating them as argument or attribute constraints.
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
      message dgettext_noop("errors", "Password must be at least %{min} characters")
    end

    validate present(:password_confirmation) do
      # `confirm` can't catch the empty confirmation when the password is
      # empty too (nil == nil), this fills that gap with the same message
      where absent(:password)
      message dgettext_noop("errors", "Passwords do not match")
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

    timestamps()
  end

  relationships do
    has_many :memberships, Membership
    many_to_many :clubs, Club, through: Membership
    has_one :settings, UserSettings

    has_many :lists, ContentList do
      destination_attribute :owner_id
    end

    # The User's place in each Conversation they're in
    has_many :participations, Participant
  end

  aggregates do
    # The Inbox tab's count
    count :unread_conversation_count, :participations do
      filter expr(unread_count > 0)
    end
  end

  identities do
    identity :unique_username, [:username] do
      message dgettext_noop("errors", "This username is already taken")
    end

    identity :only_one_administrator, [:administrator?] do
      where expr(administrator? == true)
      message dgettext_noop("errors", "An administrator already exists")
    end
  end
end
