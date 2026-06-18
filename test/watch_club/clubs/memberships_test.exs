defmodule WatchClub.Clubs.MembershipTest do
  use WatchClub.DataCase

  import WatchClub.Clubs

  alias WatchClub.Clubs.Membership

  require Ash.Query

  setup do
    admin = generate(administrator())
    club = generate(club(actor: admin))
    # Add a member
    member = generate(user())
    membership = generate(membership(club, member, role: :member))
    admin_id = admin.id
    club_id = club.id

    admin_membership =
      Membership
      |> Ash.Query.filter(club_id == ^club_id and user_id == ^admin_id)
      |> Ash.read_first!(authorize?: false)

    {:ok,
     admin: admin,
     membership: membership,
     member: member,
     membership: membership,
     admin_membership: admin_membership}
  end

  describe "leave_club/*" do
    test "member can leave a club", %{membership: membership, member: member} do
      assert :ok = leave_club(membership, [], actor: member)
    end

    test "leaving a club sends a users::<user_id> pubsub event", %{
      membership: membership,
      member: member
    } do
      topic = "users:#{membership.user_id}:memberships"
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, topic)
      assert :ok = leave_club(membership, actor: member)

      membership_id = membership.id

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       payload: %Ash.Notifier.Notification{
                         resource: Membership,
                         action: %Ash.Resource.Actions.Destroy{},
                         data: %Membership{
                           id: ^membership_id
                         }
                       }
                     },
                     500
    end

    test "leaving a club sends a clubs::<club_id> pubsub event", %{
      membership: membership,
      member: member
    } do
      topic = "clubs:#{membership.club_id}:memberships"
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, topic)
      assert :ok = leave_club(membership, actor: member)

      membership_id = membership.id

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       payload: %Ash.Notifier.Notification{
                         resource: Membership,
                         action: %Ash.Resource.Actions.Destroy{},
                         data: %Membership{
                           id: ^membership_id
                         }
                       }
                     },
                     500
    end

    test "club admin cannot leave a club", %{admin_membership: membership, admin: admin} do
      assert leave_club(membership, actor: admin)
             |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "remove_from_club/*" do
    test "club admin can remove a club member", %{membership: membership, admin: admin} do
      assert :ok = remove_from_club!(membership, actor: admin)
    end

    test "club admin cannot be removed from a club", %{admin_membership: membership, admin: admin} do
      assert remove_from_club(membership, actor: admin)
             |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "add_user_to_club/*" do
    test "the instance administrator can add an existing user to a club", %{
      admin: admin,
      admin_membership: admin_membership
    } do
      new_user = generate(user())
      club_id = admin_membership.club_id
      user_id = new_user.id

      assert %Membership{club_id: ^club_id, user_id: ^user_id, role: :member} =
               add_user_to_club!(club_id, new_user.id, actor: admin)
    end

    test "club admins cannot add users to their club", %{
      member: member,
      admin_membership: admin_membership
    } do
      # The club admin of another club is still not the instance administrator
      other_club_admin = generate(user())
      other_club = generate(club(actor: other_club_admin))

      new_user = generate(user())

      add_user_to_club(admin_membership.club_id, new_user.id, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)

      add_user_to_club(other_club.id, new_user.id, actor: other_club_admin)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "a user cannot be added to a club they already belong to", %{
      admin: admin,
      member: member,
      membership: membership
    } do
      add_user_to_club(membership.club_id, member.id, actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{} -> true
        _ -> false
      end)
    end
  end
end
