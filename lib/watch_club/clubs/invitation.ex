defmodule WatchClub.Clubs.Invitation do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  use Gettext, backend: WatchClubWeb.Gettext

  require Ash.Resource.Change.Builtins

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.Checks.{ActorIsClubMember, ActorIsClubMemberFilter}
  alias WatchClub.Clubs.{Club, Membership, MembershipRole}

  # 1 Week
  @invitation_expiration_days 7

  postgres do
    table "invitations"
    repo(WatchClub.Repo)

    references do
      reference(:club, on_delete: :delete, on_update: :update)
      reference(:inviter, on_delete: :nilify, on_update: :update)
    end
  end

  actions do
    defaults [:read, :destroy]

    read :view_invitation do
      argument :id, :uuid_v7, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))

      prepare build(
                load: [club: [:name], inviter: [:username]],
                context: %{private: %{authorize?: false}}
              )
    end

    read :list_club_invitations do
      prepare build(load: [:inviter], filter: [accepted?: false], sort: [updated_at: :desc])
    end

    create :create do
      accept [:name, :club_id, :role]

      change relate_actor(:inviter)
    end

    update :accept do
      # Creating the membership cannot be done atomically
      require_atomic? false

      # Make sure the invitation is not expired
      validate compare(:expires_at, greater_than_or_equal_to: &DateTime.utc_now/0) do
        message dgettext_noop("errors", "The invitation has expired")
      end

      validate compare(:accepted?, is_equal: {:value, false}) do
        message dgettext_noop("errors", "The invitation has already been used")
      end

      change set_attribute(:accepted?, true)

      # Create the membership as a result of accepting the invitation
      change fn changeset, %{actor: %User{} = actor} ->
        Ash.Changeset.manage_relationship(
          changeset,
          :created_membership,
          [
            %{
              club_id: Ash.Changeset.get_attribute(changeset, :club_id),
              user_id: actor.id,
              role: Ash.Changeset.get_attribute(changeset, :role)
            }
          ],
          type: :create,
          authorize?: false
        )
      end
    end
  end

  policies do
    # Fast forbid when there is no actor (unless it's for view_invitation)
    policy actor_absent() do
      authorize_if action(:view_invitation)
      forbid_if always()
    end

    # All those actions can only be executed by club admin
    policy action([:create, :destroy]) do
      authorize_if {ActorIsClubMember, role: :admin}
    end

    policy action(:destroy) do
      authorize_if expr(accepted? == false)
    end

    # Anyone with the link can view invitations
    policy action([:view_invitation, :accept]) do
      authorize_if always()
    end

    # Only club admins and invitees can read invitations
    policy action([:read, :list_club_invitations]) do
      authorize_if {ActorIsClubMemberFilter, role: :admin}
    end
  end

  preparations do
    prepare build(load: [:expired?])
  end

  validations do
    validate string_length(:name, min: 3) do
      message dgettext_noop("errors", "Name must be at least %{min} characters")
    end

    validate string_length(:name, max: 30) do
      message dgettext_noop("errors", "Name cannot be longer than %{max} characters")
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, public?: true

    attribute :role, MembershipRole, allow_nil?: false, public?: true

    attribute :accepted?, :boolean do
      source :accepted
      public? true
      allow_nil? false
      default false
    end

    attribute :expires_at, :utc_datetime_usec do
      public? true
      allow_nil? false

      default fn ->
        DateTime.utc_now() |> DateTime.add(@invitation_expiration_days, :day)
      end
    end

    timestamps()
  end

  relationships do
    belongs_to :club, Club, allow_nil?: false
    belongs_to :inviter, User, allow_nil?: false

    has_one :created_membership, Membership do
      destination_attribute :invitation_id
    end
  end

  calculations do
    calculate :expired?, :boolean, expr(expires_at <= now()) do
      public? true
    end
  end
end
