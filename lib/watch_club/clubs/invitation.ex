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
    end
  end

  state_machine do
    state_attribute :status
    initial_states [:sent]
    default_initial_state :sent

    # There is no :expired status, it is computed from :expires_at > now()
    transitions do
      transition :accept, from: :sent, to: :accepted
      transition :resend, from: [:sent, :cancelled], to: :sent
      transition :cancel, from: :sent, to: :cancelled
    end
  end

  actions do
    defaults [:read]

    read :view_invitation do
      argument :id, :uuid_v7, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
    end

    read :list_club_invitations do
      argument :club_id, :uuid_v7, allow_nil?: false

      argument :statuses, {:array, :atom} do
        constraints items: [one_of: [:sent, :accepted, :cancelled]]
      end

      filter expr(club_id == ^arg(:club_id))
      filter expr(is_nil(^arg(:statuses)) or status in ^arg(:statuses))
    end

    create :create do
      accept [:email, :club_id, :role]

      validate {WatchClub.Clubs.Validations.UserNotInClub, [email: :email, club_id: :club_id]}
    end

    update :resend do
      change atomic_set(
               :expires_at,
               expr(datetime_add(now(), ^@invitation_expiration_days, :day))
             )

      change transition_state(:sent)
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

    # Only the invitee can accept an invitation
    policy action(:accept) do
      authorize_if expr(email == ^actor(:email))
    end

    # All those actions can only be executed by club admin
    policy action([:create, :resend, :cancel, :list_club_invitations]) do
      # So that :list_club_invitations raises Forbidden error instead of returning []
      access_type :strict
      authorize_if {ActorIsClubMember, role: :admin}
    end

    # Anyone with the link can view invitations
    policy action(:view_invitation) do
      authorize_if always()
    end

    # Only club admins and invitees can read invitations
    policy action(:read) do
      authorize_if {ActorIsClubMemberFilter, role: :admin}
      authorize_if expr(email == ^actor(:email))
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :email, :ci_string, allow_nil?: false, public?: true

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
    belongs_to :created_membership, Membership
  end

  identities do
    identity :club_and_email, [:club_id, :email]
    identity :created_membership_id, [:created_membership_id]
  end
end
