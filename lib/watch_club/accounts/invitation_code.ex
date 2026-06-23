defmodule WatchClub.Accounts.InvitationCode do
  @moduledoc """
  An instance-wide Invitation Code created by the Instance Administrator that lets new
  people register and, on doing so, join zero or more clubs as club members.

  Redeemable only while its derived `status` is `:active`
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.{ClubInvitation, InvitationCodeStatus}
  alias WatchClub.Clubs.Club

  postgres do
    table "invitation_codes"
    repo WatchClub.Repo
  end

  @invitation_expiration_days 7

  actions do
    defaults [:read, :destroy]

    read :view_invitation do
      description "View the invitation granted by a code"
      argument :code, :string, allow_nil?: false
      get? true
      filter expr(code == ^arg(:code))

      # Anyone is able to view a club name through an invitation
      prepare build(
                load: [clubs: [:name]],
                context: %{private: %{authorize?: false}}
              )
    end

    create :create do
      description "Create an invitation code"
      accept [:code, :max_uses]

      argument :club_ids, {:array, :uuid_v7} do
        allow_nil? false
        # Default is needed so that the form default value is [] and not nil
        default []
      end

      change manage_relationship(:club_ids, :clubs, type: :append)
      load [:club_ids]
    end

    update :update do
      description "Update an invitation code associated clubs and max uses"
      primary? true
      require_atomic? false

      accept [:max_uses]
      argument :club_ids, {:array, :uuid_v7}

      validate compare(:max_uses, greater_than_or_equal_to: :uses) do
        # nil max_uses means unlimited, so only guard when a limit is set
        where present(:max_uses)

        message dgettext_noop(
                  "errors",
                  "This invitation has already been used more than that"
                )
      end

      change manage_relationship(:club_ids, :clubs, type: :append_and_remove)
      change load(:club_ids)
    end

    update :use do
      description "Uses an invitation code to signup a user"

      validate compare(:expires_at, greater_than: &DateTime.utc_now/0) do
        message dgettext_noop("errors", "The invitation has expired")
      end

      validate WatchClub.Accounts.Validations.InvitationNotUsed do
        message dgettext_noop("errors", "The invitation has already been used")
      end

      # The action is atomic: the validations above and the increment compile
      # into a single UPDATE, so concurrent accepts serialize on the row lock
      # and can never exceed max_uses.
      change increment(:uses)
    end
  end

  policies do
    policy action(:view_invitation) do
      description "Anyone with the link can view an invitation"
      authorize_if always()
    end

    policy action(:use) do
      description "Invitation codes are used by new people registering, before they have an account"
      authorize_if always()
    end

    policy action([:create, :update, :destroy, :read]) do
      description "Invitation codes are created and managed only by the Instance Administrator"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    publish_all :create, ["users", "admin"]
    publish_all :update, ["users", "admin"]
    publish_all :destroy, ["users", "admin"]
  end

  preparations do
    prepare build(load: [:club_ids, :status])
  end

  validations do
    validate string_length(:code, min: 6) do
      where changing(:code)
      message dgettext_noop("errors", "Code must be at least %{min} characters")
    end

    validate match(:code, ~r/^[A-Z0-9_]+$/) do
      where changing(:code)

      message dgettext_noop(
                "errors",
                "Code can only contain upper case letters, numbers and _"
              )
    end

    validate string_length(:code, max: 100) do
      where changing(:code)
      message dgettext_noop("errors", "Code cannot be longer than %{max} characters")
    end

    validate compare(:max_uses, greater_than_or_equal_to: 1) do
      where changing(:max_uses)
      message dgettext_noop("errors", "Max uses must be at least %{greater_than_or_equal_to}")
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :code, :string do
      allow_nil? false
      public? true
    end

    attribute :max_uses, :integer do
      description "Maximum number of accounts this invitation can create; nil is unlimited."
      public? true
    end

    attribute :uses, :integer do
      description "Number of accounts created with this invitation"
      public? true
      default 0
    end

    attribute :expires_at, :utc_datetime_usec do
      public? true
      allow_nil? false

      # Expiration date is set in an anonymous function to avoid being computed at compile time
      default fn ->
        DateTime.utc_now() |> DateTime.add(@invitation_expiration_days, :day)
      end
    end

    timestamps()
  end

  relationships do
    has_many :club_invitations, ClubInvitation

    many_to_many :clubs, Club do
      through ClubInvitation
      source_attribute_on_join_resource :invitation_code_id
      destination_attribute_on_join_resource :club_id
    end
  end

  calculations do
    calculate :status,
              InvitationCodeStatus,
              expr(
                cond do
                  not is_nil(max_uses) and uses >= max_uses -> :used
                  expires_at <= now() -> :expired
                  true -> :active
                end
              ) do
      public? true
    end
  end

  aggregates do
    # This is required to populate the edit form
    # https://ash-phoenix.hexdocs.pm/forms-for-relationships-between-existing-records.html
    list :club_ids, :clubs, :id
  end

  identities do
    # The code is the redemption key (view_invitation is a get by code)
    identity :unique_code, [:code] do
      message dgettext_noop("errors", "This code is already used by another invitation")
    end
  end
end
