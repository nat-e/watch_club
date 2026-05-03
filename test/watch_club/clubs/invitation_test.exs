defmodule WatchClub.Clubs.InvitationTest do
  use WatchClub.DataCase

  alias WatchClub.Clubs.{Invitation, Membership, MembershipRole}
  import WatchClub.Clubs

  setup do
    admin = generate(administrator())
    club = generate(club(actor: admin))
    # Add a member
    member = generate(user())
    generate(membership(club, member, role: :member))

    {:ok, admin: admin, club: club, member: member}
  end

  describe "create_invitation/*" do
    test "creates an invitation", %{admin: admin, club: club} do
      club_id = club.id

      assert %Invitation{
               club_id: ^club_id,
               status: :available,
               role: :admin,
               expires_at: %DateTime{} = expires_at
             } =
               create_invitation!(%{name: "Nate", club_id: club.id, role: :admin},
                 actor: admin,
                 load: :status
               )

      assert DateTime.after?(expires_at, DateTime.utc_now())
    end

    test "only club admins can create invitations", %{club: club, member: member} do
      create_invitation(%{name: "Nate", club_id: club.id, role: :admin}, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "accept_invitation/*" do
    for role <- MembershipRole.values() do
      test "accepts an invitation and creates a :#{role} membership", %{club: club, admin: admin} do
        invitation_role = unquote(role)
        invitation = generate(invitation(club, admin, role: invitation_role))
        invitee = generate(user())
        invitee_id = invitee.id

        assert %Invitation{
                 status: :accepted,
                 created_membership: %Membership{user_id: ^invitee_id, role: ^invitation_role}
               } =
                 accept_invitation!(invitation,
                   load: [:status, :created_membership],
                   actor: invitee
                 )
      end
    end

    test "cannot accept an expired invitation", %{club: club, admin: admin} do
      invitee = generate(user())

      generate(invitation(club, admin))
      |> Ash.Seed.update!(%{
        status: :available,
        expires_at: DateTime.utc_now() |> DateTime.add(-1, :day)
      })
      |> accept_invitation(actor: invitee)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :expires_at} -> true
        _ -> false
      end)
    end

    test "cannot accept an invitation twice", %{club: club, admin: admin} do
      invitee = generate(user())

      generate(invitation(club, admin))
      |> Ash.Seed.update!(%{
        status: :accepted,
        created_membership: generate(membership(club, invitee))
      })
      |> accept_invitation(actor: invitee)
      |> assert_has_error(Ash.Error.Invalid, fn
        %AshStateMachine.Errors.NoMatchingTransition{} -> true
        _ -> false
      end)
    end

    test "cannot accept a cancelled invitation", %{club: club, admin: admin} do
      invitee = generate(user())

      generate(invitation(club, admin))
      |> Ash.Seed.update!(%{
        status: :cancelled
      })
      |> accept_invitation(actor: invitee)
      |> assert_has_error(Ash.Error.Invalid, fn
        %AshStateMachine.Errors.NoMatchingTransition{} -> true
        _ -> false
      end)
    end
  end

  describe "cancel_invitation/*" do
    test "cancels the invitation", %{club: club, admin: admin} do
      invitation = generate(invitation(club, admin))

      assert %Invitation{
               status: :cancelled
             } = cancel_invitation!(invitation, actor: admin)
    end

    test "cannot cancel an accepted invitation", %{club: club, admin: admin} do
      invitee = generate(user())

      generate(invitation(club, admin))
      |> Ash.Seed.update!(%{
        status: :accepted,
        created_membership: generate(membership(club, invitee))
      })
      |> cancel_invitation(actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %AshStateMachine.Errors.NoMatchingTransition{} -> true
        _ -> false
      end)
    end

    test "only admin can cancel an invitation", %{club: club, admin: admin, member: member} do
      generate(invitation(club, admin))
      |> cancel_invitation(actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "list_club_invitations/*" do
    test "lists all club invitations when no filter", %{club: club, admin: admin} do
      invitation(club, admin) |> generate_many(3)

      invitations = list_club_invitations!(%{club_id: club.id}, actor: admin)

      assert length(invitations) == 3
    end

    test "shows only invitation with matching statuses", %{club: club, admin: admin} do
      invitation(club, admin) |> generate_many(5)
      invitation(club, admin) |> generate() |> Ash.Seed.update!(%{status: :cancelled})
      invitation(club, admin) |> generate() |> Ash.Seed.update!(%{status: :accepted})

      invitations =
        list_club_invitations!(%{club_id: club.id, statuses: [:cancelled, :accepted]},
          actor: admin
        )

      assert length(invitations) == 2
    end

    test "only admins can list invitations", %{club: club, admin: admin, member: member} do
      invitation(club, admin) |> generate_many(3)

      list_club_invitations(%{club_id: club.id}, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "view_invitation/*" do
    test "anyone with the ID can view the invitation", %{club: club, admin: admin} do
      invitation = generate(invitation(club, admin))

      assert %Invitation{} = view_invitation!(invitation.id)
    end
  end
end
