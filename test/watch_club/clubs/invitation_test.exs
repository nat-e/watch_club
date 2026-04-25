defmodule WatchClub.Clubs.InvitationTest do
  use WatchClub.DataCase

  alias WatchClub.Clubs.{Club, Invitation, Membership, MembershipRole}
  import WatchClub.Clubs

  setup do
    admin = generate(user())
    club = generate(club(actor: admin))
    # Add a member
    member = generate(user())
    generate(membership(club, member, role: :member))

    {:ok, admin: admin, club: club, member: member}
  end

  describe "invite_user/*" do
    test "invites a user to the club", %{admin: admin, club: club} do
      club_id = club.id

      assert %Invitation{
               club_id: ^club_id,
               email: %Ash.CiString{} = email,
               status: :sent,
               role: :admin,
               expires_at: %DateTime{} = expires_at
             } =
               invite_user!(%{email: "N@test.com", club_id: club.id, role: :admin},
                 actor: admin,
                 load: :status
               )

      # TODO: Test that an email is sent
      # assert invite.status == :sent
      assert Ash.CiString.compare(email, "n@test.com")
      assert DateTime.after?(expires_at, DateTime.utc_now())
    end

    test "cannot invite an existing member", %{club: club, admin: admin, member: member} do
      invite_user(%{email: member.email, club_id: club.id, role: :member}, actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{
          field: :email,
          message: "user is already a member of the club"
        } ->
          true

        _ ->
          false
      end)
    end

    test "cannot invite an existing member with different email case", %{
      club: club,
      admin: admin
    } do
      member = generate(user(email: "test@example.com"))
      generate(membership(club, member, role: :member))

      invite_user(%{email: "TEST@example.com", club_id: club.id, role: :member},
        actor: admin
      )
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{
          field: :email,
          message: "user is already a member of the club"
        } ->
          true

        _ ->
          false
      end)
    end

    test "only club admins can invite members", %{club: club, member: member} do
      invite_user(%{email: "new@test.com", club_id: club.id, role: :admin}, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "accept_invitation/*" do
    for role <- MembershipRole.values() do
      test "accepts an invitation and creates a :#{role} membership", %{
        club: %Club{} = club
      } do
        invitation_role = unquote(role)
        invitation = generate(invitation(club, role: invitation_role))
        invitee = generate(user(%{email: invitation.email}))
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

    test "cannot accept an invitation for another user", %{club: club} do
      generate(invitation(club, role: :admin))
      |> accept_invitation(actor: generate(user()))
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "cannot accept an expired invitation", %{club: club} do
      invitee = generate(user())

      generate(invitation(club, email: invitee.email))
      |> Ash.Seed.update!(%{
        status: :sent,
        expires_at: DateTime.utc_now() |> DateTime.add(-1, :day)
      })
      |> accept_invitation(actor: invitee)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :expires_at} -> true
        _ -> false
      end)
    end

    test "cannot accept an invitation twice", %{club: club} do
      invitee = generate(user())

      generate(invitation(club, email: invitee.email))
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

    test "cannot accept a cancelled invitation", %{club: club} do
      invitee = generate(user())

      generate(invitation(club, email: invitee.email))
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

  describe "resend_invitation/*" do
    test "resends an email and extends the invitation", %{club: club, admin: admin} do
      invitation =
        generate(invitation(club))
        |> Ash.Seed.update!(%{
          expires_at: DateTime.utc_now() |> DateTime.add(-1, :day)
        })

      assert %Invitation{
               status: :sent,
               expires_at: %DateTime{} = expires_at
             } = resend_invitation!(invitation, actor: admin, load: :status)

      # TODO: Test that an email is re-sent

      assert DateTime.after?(expires_at, DateTime.utc_now())
    end

    test "cannot resend an accepted invitation", %{club: club, admin: admin} do
      invitee = generate(user())

      generate(invitation(club))
      |> Ash.Seed.update!(%{
        status: :accepted,
        created_membership: generate(membership(club, invitee))
      })
      |> resend_invitation(actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %AshStateMachine.Errors.NoMatchingTransition{} -> true
        _ -> false
      end)
    end

    test "only admins can resend invitations", %{club: club, member: member} do
      generate(invitation(club))
      |> resend_invitation(actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "cancel_invitation/*" do
    test "cancels the invitation", %{club: club, admin: admin} do
      invitation = generate(invitation(club))

      assert %Invitation{
               status: :cancelled
             } = cancel_invitation!(invitation, actor: admin)
    end

    test "cannot cancel an accepted invitation", %{club: club, admin: admin} do
      invitee = generate(user())

      generate(invitation(club))
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

    test "only admin can cancel an invitation", %{club: club, member: member} do
      generate(invitation(club))
      |> cancel_invitation(actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "list_club_invitations/*" do
    test "lists all club invitations when no filter", %{club: club, admin: admin} do
      invitation(club) |> generate_many(3)

      invitations = list_club_invitations!(%{club_id: club.id}, actor: admin)

      assert length(invitations) == 3
    end

    test "shows only invitation with matching statuses", %{club: club, admin: admin} do
      invitation(club) |> generate_many(5)
      invitation(club) |> generate() |> Ash.Seed.update!(%{status: :cancelled})
      invitation(club) |> generate() |> Ash.Seed.update!(%{status: :accepted})

      invitations =
        list_club_invitations!(%{club_id: club.id, statuses: [:cancelled, :accepted]},
          actor: admin
        )

      assert length(invitations) == 2
    end

    test "only admins can list invitations", %{club: club, member: member} do
      invitation(club) |> generate_many(3)

      list_club_invitations(%{club_id: club.id}, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "view_invitation/*" do
    test "anyone with the ID can view the invitation", %{club: club} do
      invitation = generate(invitation(club))

      assert %Invitation{} = view_invitation!(invitation.id)
    end
  end
end
