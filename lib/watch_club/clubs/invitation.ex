defmodule WatchClub.Clubs.Invitation do
  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.Checks.{ActorIsClubMember, ActorIsClubMemberFilter}
  alias WatchClub.Clubs.{Club, Membership, MembershipRole}

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  # 1 Week
  @invitation_expiration_days 7

  postgres do
    table "invitations"
    repo(WatchClub.Repo)

    references do
      reference(:club, on_delete: :delete, on_update: :update)
      reference(:inviter, on_delete: :delete, on_update: :update)
    end
  end

  state_machine do
    state_attribute :status
    initial_states [:available]
    default_initial_state :available

    # There is no :expired status, it is computed from :expires_at > now()
    transitions do
      transition :accept, from: :available, to: :accepted
      transition :cancel, from: :available, to: :cancelled
    end
  end

  actions do
    defaults [:read]

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
      argument :club_id, :uuid_v7, allow_nil?: false

      argument :statuses, {:array, :atom} do
        constraints items: [one_of: [:available, :accepted, :cancelled]]
      end

      filter expr(club_id == ^arg(:club_id))
      filter expr(is_nil(^arg(:statuses)) or status in ^arg(:statuses))
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
        message "invitation has expired"
      end

      change transition_state(:accepted)

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

    update :cancel do
      change transition_state(:cancelled)
    end
  end

  policies do
    # Fast forbid when there is no actor (unless it's for view_invitation)
    policy actor_absent() do
      authorize_if action(:view_invitation)
      forbid_if always()
    end

    # All those actions can only be executed by club admin
    policy action([:create, :cancel, :list_club_invitations]) do
      # So that :list_club_invitations raises Forbidden error instead of returning []
      access_type :strict
      authorize_if {ActorIsClubMember, role: :admin}
    end

    # Anyone with the link can view invitations
    policy action([:view_invitation, :accept]) do
      authorize_if always()
    end

    # Only club admins and invitees can read invitations
    policy action(:read) do
      authorize_if {ActorIsClubMemberFilter, role: :admin}
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, public?: true

    attribute :role, MembershipRole, allow_nil?: false, public?: true

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
    belongs_to :created_membership, Membership
  end

  identities do
    identity :created_membership_id, [:created_membership_id]
  end
end
