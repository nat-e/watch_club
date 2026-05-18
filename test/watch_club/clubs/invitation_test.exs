defmodule WatchClub.Clubs.InvitationTest do
  use WatchClub.DataCase

  import WatchClub.Clubs

  alias WatchClub.Clubs.{Invitation, Membership}

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
               accepted?: false,
               expires_at: %DateTime{} = expires_at
             } =
               create_invitation!(%{name: "Nate", club_id: club.id}, actor: admin)

      assert DateTime.after?(expires_at, DateTime.utc_now())
    end

    test "only club admins can create invitations", %{club: club, member: member} do
      create_invitation(%{name: "Nate", club_id: club.id}, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "accept_invitation/*" do
    test "accepts an invitation and creates a club member membership", %{club: club, admin: admin} do
      invitation = generate(invitation(club, admin))
      invitee = generate(user())
      invitee_id = invitee.id

      assert %Invitation{
               accepted?: true,
               created_membership: %Membership{user_id: ^invitee_id, role: :member}
             } =
               accept_invitation!(invitation,
                 load: [:created_membership],
                 actor: invitee
               )
    end

    test "accepts an invitation sends a user::<user_id> pubsub event", %{club: club, admin: admin} do
      invitation = generate(invitation(club, admin))
      invitee = generate(user())
      invitee_id = invitee.id
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "users:#{invitee_id}:memberships")

      invitation =
        accept_invitation!(invitation,
          load: [:created_membership],
          actor: invitee
        )

      membership_id = invitation.created_membership.id

      assert_receive %Ash.Notifier.Notification{
                       resource: Membership,
                       action: %Ash.Resource.Actions.Create{},
                       data: %Membership{
                         id: ^membership_id
                       }
                     },
                     500
    end

    test "accepts an invitation sends a club::<club_id> pubsub event", %{club: club, admin: admin} do
      invitation = generate(invitation(club, admin))
      invitee = generate(user())
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "clubs:#{club.id}:memberships")

      invitation =
        accept_invitation!(invitation,
          load: [:created_membership],
          actor: invitee
        )

      membership_id = invitation.created_membership.id

      assert_receive %Ash.Notifier.Notification{
                       resource: Membership,
                       action: %Ash.Resource.Actions.Create{},
                       data: %Membership{
                         id: ^membership_id
                       }
                     },
                     500
    end

    test "cannot accept an expired invitation", %{club: club, admin: admin} do
      invitee = generate(user())

      generate(invitation(club, admin))
      |> Ash.Seed.update!(%{
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
        accepted?: true,
        created_membership: generate(membership(club, invitee))
      })
      |> accept_invitation(actor: invitee)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :accepted?} -> true
        _ -> false
      end)
    end
  end

  describe "view_invitation/*" do
    test "anyone with the ID can view the invitation", %{club: club, admin: admin} do
      invitation = generate(invitation(club, admin))

      assert %Invitation{} = view_invitation!(invitation.id)
    end
  end
end
