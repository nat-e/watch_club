defmodule WatchClub.Clubs.ClubTest do
  use WatchClub.DataCase

  import WatchClub.Clubs

  alias WatchClub.Clubs.{Club, Library, Membership}

  require Ash.Query

  setup do
    admin = generate(administrator())
    club = generate(club(actor: admin))
    # Add a member
    member = generate(user())
    generate(membership(club, member, role: :member))

    {:ok, admin: admin, club: club, member: member}
  end

  describe "create_club/*" do
    test "creates a club with the user as admin", %{admin: admin} do
      admin_id = admin.id
      # No need to load :memberships. They are expected to be populated
      assert %Club{
               name: "My Club",
               memberships: [%Membership{user_id: ^admin_id, role: :admin}]
             } =
               create_club!(%{name: "My Club"}, actor: admin)
    end

    test "only administrator can create clubs" do
      other_user = generate(user())

      assert_raise Ash.Error.Forbidden, fn ->
        create_club!(%{name: "My Club"}, actor: other_user)
      end
    end

    test "cannot create a club without an actor" do
      assert_raise Ash.Error.Forbidden, fn -> create_club!(%{name: "My Club"}) end
    end

    test "cannot create a club with a name less than 2 characters", %{admin: admin} do
      create_club(%{name: "A"}, actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :name} -> true
        _ -> false
      end)
    end

    test "cannot create a club with a name larger than 30 characters", %{admin: admin} do
      create_club(%{name: String.duplicate("A", 31)}, actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :name} -> true
        _ -> false
      end)
    end
  end

  describe "list_clubs/*" do
    test "shows the clubs the user has access to" do
      other_user = generate(user())
      club(actor: other_user) |> generate_many(2)

      clubs = list_clubs!(actor: other_user)

      assert length(clubs) == 2
    end

    test "cannot list clubs without an actor" do
      assert_raise Ash.Error.Forbidden, fn -> list_clubs!() end
    end
  end

  describe "get_club_by_id/*" do
    test "returns the club for members", %{club: club, member: member} do
      club_id = club.id
      %Club{id: ^club_id} = get_club_by_id!(club_id, actor: member)
    end

    test "non-members cannot access the club", %{club: club} do
      another_user = generate(user())

      get_club_by_id(club.id, actor: another_user)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Query.NotFound{} -> true
        _ -> false
      end)
    end

    test "cannot access the club without an actor", %{club: club} do
      assert_raise Ash.Error.Forbidden, fn -> get_club_by_id!(club.id) end
    end
  end

  describe "reorder_libraries/*" do
    test "admins can reorder libraries", %{club: club, admin: admin} do
      first = generate(library(club, name: "First", index: 0))
      second = generate(library(club, name: "Second", index: 1))
      third = generate(library(club, name: "Third", index: 2))

      assert %Club{} = reorder_libraries!(club.id, [third.id, first.id, second.id], actor: admin)

      assert [
               %Library{name: "Third", index: 0},
               %Library{name: "First", index: 1},
               %Library{name: "Second", index: 2}
             ] = list_club_libraries!(club.id, actor: admin)
    end

    test "rejects orders that do not include each library exactly once", %{
      club: club,
      admin: admin
    } do
      first = generate(library(club, index: 0))
      second = generate(library(club, index: 1))
      generate(library(club, index: 2))

      reorder_libraries(club.id, [first.id, second.id], actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Action.InvalidArgument{field: :library_ids} -> true
        _ -> false
      end)
    end

    test "members cannot reorder libraries", %{club: club, member: member} do
      reorder_libraries(club.id, [], actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "cannot reorder libraries without an actor", %{club: club} do
      reorder_libraries(club.id, [])
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "update_club/*" do
    test "admins can modify the club", %{club: club, admin: admin} do
      %Club{name: "New name"} = update_club!(club, %{name: "New name"}, actor: admin)
    end

    test "sends a club:<club_id> pubsub event", %{club: club, admin: admin} do
      club_id = club.id
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "club:#{club_id}")
      %Club{name: "New name"} = update_club!(club, %{name: "New name"}, actor: admin)

      assert_receive %Ash.Notifier.Notification{
                       resource: Club,
                       action: %Ash.Resource.Actions.Update{},
                       data: %Club{id: ^club_id}
                     },
                     500
    end

    test "members cannot modify the club", %{club: club, member: member} do
      assert_raise Ash.Error.Forbidden, fn ->
        update_club!(club, %{name: "New name"}, actor: member)
      end
    end

    test "cannot modify club without an actor", %{club: club} do
      assert_raise Ash.Error.Forbidden, fn -> update_club!(club, %{name: "New name"}) end
    end
  end

  describe "add_club_members/*" do
    test "club admins can add existing users to their club", %{club: club, admin: admin} do
      new_user = generate(user())
      club_id = club.id
      user_id = new_user.id

      add_club_members!(club, [user_id], actor: admin)

      assert %Membership{role: :member} =
               Membership
               |> Ash.Query.filter(club_id == ^club_id and user_id == ^user_id)
               |> Ash.read_one!(authorize?: false)
    end

    test "members cannot add users to the club", %{club: club, member: member} do
      new_user = generate(user())

      add_club_members(club, [new_user.id], actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "admins of another club cannot add users to this club", %{club: club} do
      other_club_admin = generate(user())
      generate(club(actor: other_club_admin))
      new_user = generate(user())

      add_club_members(club, [new_user.id], actor: other_club_admin)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "a user cannot be added to a club they already belong to", %{
      club: club,
      admin: admin,
      member: member
    } do
      add_club_members(club, [member.id], actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{} -> true
        _ -> false
      end)
    end
  end

  describe "destroy_club/*" do
    test "admins can destroy the club", %{club: club, admin: admin} do
      assert destroy_club!(club, actor: admin)
    end

    test "members cannot destroy the club", %{club: club, member: member} do
      assert_raise Ash.Error.Forbidden, fn ->
        destroy_club!(club, actor: member)
      end
    end

    test "cannot destroy club without an actor", %{club: club} do
      assert_raise Ash.Error.Forbidden, fn -> destroy_club!(club) end
    end
  end

  describe "relationship: memberships" do
    test "admins can see club memberships", %{club: club, admin: admin} do
      club = Ash.load!(club, :memberships, actor: admin)
      assert [%Membership{}, %Membership{}] = club.memberships
    end

    test "members can see club memberships", %{club: club, member: member} do
      club = Ash.load!(club, :memberships, actor: member)
      assert [%Membership{}, %Membership{}] = club.memberships
    end

    test "users outside the club cannot see its memberships", %{club: club} do
      club = Ash.load!(club, :memberships, actor: generate(user()))
      assert [] = club.memberships
    end
  end
end
