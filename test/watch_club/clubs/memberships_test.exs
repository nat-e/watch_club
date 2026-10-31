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

    test "leaving a club sends a user:<user_id> pubsub event", %{
      membership: membership,
      member: member
    } do
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "user:#{membership.user_id}")
      assert :ok = leave_club(membership, actor: member)

      membership_id = membership.id

      assert_receive %Ash.Notifier.Notification{
                       resource: Membership,
                       action: %Ash.Resource.Actions.Destroy{},
                       data: %Membership{id: ^membership_id}
                     },
                     500
    end

    test "leaving a club sends a memberships:club:<club_id> pubsub event", %{
      membership: membership,
      member: member
    } do
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "memberships:club:#{membership.club_id}")
      assert :ok = leave_club(membership, actor: member)

      membership_id = membership.id

      assert_receive %Ash.Notifier.Notification{
                       resource: Membership,
                       action: %Ash.Resource.Actions.Destroy{},
                       data: %Membership{id: ^membership_id}
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
end
