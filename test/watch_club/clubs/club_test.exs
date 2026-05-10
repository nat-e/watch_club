defmodule WatchClub.Clubs.ClubTest do
  use WatchClub.DataCase

  import WatchClub.Clubs

  alias WatchClub.Clubs.{Club, Invitation, Library, Membership}

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

      assert [
               %Library{name: "Third", index: 0},
               %Library{name: "First", index: 1},
               %Library{name: "Second", index: 2}
             ] =
               reorder_libraries!(club.id, %{library_ids: [third.id, first.id, second.id]},
                 actor: admin
               )

      assert [
        %Library{name: "Third", index: 0},
        %Library{name: "First", index: 1},
        %Library{name: "Second", index: 2}
             ] = list_club_libraries!(club.id)
    end

    test "rejects orders that do not include each library exactly once", %{
      club: club,
      admin: admin
    } do
      first = generate(library(club, index: 0))
      second = generate(library(club, index: 1))
      generate(library(club, index: 2))

      reorder_libraries(club.id, %{library_ids: [first.id, second.id]}, actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Action.InvalidArgument{field: :library_ids} -> true
        _ -> false
      end)
    end

    test "members cannot reorder libraries", %{club: club, member: member} do
      reorder_libraries(club.id, %{}, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "cannot reorder libraries without an actor", %{club: club} do
      reorder_libraries(club.id, %{})
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "update_club/*" do
    test "admins can modify the club", %{club: club, admin: admin} do
      %Club{name: "New name"} = update_club!(club, %{name: "New name"}, actor: admin)
    end

    test "sends a clubs:<club_id> pubsub event", %{club: club, admin: admin} do
      club_id = club.id
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "clubs:#{club_id}")
      %Club{name: "New name"} = update_club!(club, %{name: "New name"}, actor: admin)

      assert_receive %Ash.Notifier.Notification{
                       resource: Club,
                       action: %Ash.Resource.Actions.Update{},
                       data: %Club{
                         id: ^club_id
                       }
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

  describe "relationship: invitations" do
    test "admins can see club invitations", %{club: club, admin: admin} do
      invitation(club, admin) |> generate_many(2)

      club = Ash.load!(club, :invitations, actor: admin)
      assert [%Invitation{}, %Invitation{}] = club.invitations
    end
  end

  describe "relationship: memberships" do
    test "admins can see club memberships", %{club: club, admin: admin} do
      club = Ash.load!(club, :memberships, actor: admin)
      assert [%Membership{}, %Membership{}] = club.memberships
    end

    test "members can only see their membership", %{club: club} do
      other_user = generate(user())
      membership_id = generate(membership(club, other_user, role: :member)).id

      club = Ash.load!(club, :memberships, actor: other_user)

      assert [%Membership{id: ^membership_id}] = club.memberships
    end
  end
end
