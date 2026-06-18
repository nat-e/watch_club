defmodule WatchClub.Accounts.UserTest do
  use WatchClub.DataCase

  alias WatchClub.Accounts.{InvitationCode, User}
  alias WatchClub.Clubs.Membership

  import WatchClub.Accounts

  describe "create_administrator/*" do
    test "creates the administrator if there are none" do
      assert %User{administrator?: true, settings: %{locale: :fr_FR}} =
               create_administrator!(%{
                 username: "nate",
                 password: "passw0rd",
                 password_confirmation: "passw0rd",
                 locale: :fr_FR
               })
    end

    test "fails if there is already a administrator" do
      generate(administrator())

      create_administrator(%{
        username: "nate",
        password: "passw0rd",
        password_confirmation: "passw0rd",
        locale: :en_US
      })
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{
          field: :administrator?
        } ->
          true

        _ ->
          false
      end)
    end

    test "fails with an invalid locale" do
      create_administrator(%{
        username: "nate",
        password: "passw0rd",
        password_confirmation: "passw0rd",
        locale: :it_IT
      })
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidArgument{field: :locale} -> true
        _ -> false
      end)
    end
  end

  describe "administrator_exists?/*" do
    test "true when exists" do
      generate(administrator())

      assert {:ok, true} = administrator_exists()
    end

    test "false when not setup" do
      assert {:ok, false} = administrator_exists()
    end
  end

  describe "get_administrator?/*" do
    test "returns the admin when exist" do
      admin = generate(administrator())
      admin_id = admin.id

      assert %User{id: ^admin_id} = get_administrator!(actor: admin)
    end

    test "only the administrator can get the administrator" do
      other_user = generate(user())

      assert_raise Ash.Error.Forbidden, fn -> get_administrator!(actor: other_user) end
    end
  end

  describe "sign_in/*" do
    test "signs the user in with their username and password" do
      password = "passw0rd"
      user = generate(user(password: password, password_confirmation: password))
      user_id = user.id

      assert %User{id: ^user_id} = sign_in!(%{username: user.username, password: password})
    end

    test "fails when the username does not exist" do
      password = "passw0rd"
      generate(user(password: password, password_confirmation: password))

      assert_raise Ash.Error.Forbidden, fn ->
        sign_in!(%{username: "random", password: password})
      end
    end

    test "fails when the password is incorrect" do
      user = generate(user())

      assert_raise Ash.Error.Forbidden, fn ->
        sign_in!(%{username: user.username, password: "wrongpassword"})
      end
    end
  end

  describe "register_with_password/*" do
    setup do
      admin = generate(administrator())
      club = generate(club(actor: admin))
      other_club = generate(club(actor: admin))

      {:ok, admin: admin, club: club, other_club: other_club}
    end

    test "registering uses the invitation code and joins the granted clubs", %{
      admin: admin,
      club: club,
      other_club: other_club
    } do
      invitation_code =
        generate(invitation_code(actor: admin, club_ids: [club.id, other_club.id]))

      assert %User{settings: %{locale: :en_US}} =
               user =
               register_with_password!(%{
                 username: "nate",
                 password: "passw0rd",
                 password_confirmation: "passw0rd",
                 invitation_code: invitation_code.code,
                 locale: :en_US
               })

      memberships = Ash.load!(user, :memberships, authorize?: false).memberships

      assert memberships |> Enum.map(& &1.club_id) |> Enum.sort() ==
               Enum.sort([club.id, other_club.id])

      assert Enum.all?(memberships, &(&1.role == :member))

      assert %InvitationCode{uses: 1} =
               Ash.get!(InvitationCode, invitation_code.id, authorize?: false)
    end

    test "an invitation code granting zero clubs registers the user without memberships", %{
      admin: admin
    } do
      invitation_code = generate(invitation_code(actor: admin, club_ids: []))

      user =
        register_with_password!(%{
          username: "nate",
          password: "passw0rd",
          password_confirmation: "passw0rd",
          invitation_code: invitation_code.code,
          locale: :en_US
        })

      assert Ash.load!(user, :memberships, authorize?: false).memberships == []
    end

    test "users can't register without an invitation code" do
      assert register_with_password(%{
               username: "nate",
               password: "passw0rd",
               password_confirmation: "passw0rd"
             })
             |> assert_has_error(Ash.Error.Invalid, fn
               %Ash.Error.Changes.Required{
                 field: :invitation_code
               } ->
                 true

               _ ->
                 false
             end)
    end

    test "users can't register with a used invitation code", %{admin: admin, club: club} do
      invitation_code =
        generate(invitation_code(actor: admin, club_ids: [club.id], max_uses: 1))
        |> Ash.Seed.update!(%{uses: 1})

      assert register_with_password(%{
               username: "nate",
               password: "passw0rd",
               password_confirmation: "passw0rd",
               invitation_code: invitation_code.code,
               locale: :en_US
             })
             |> assert_has_error(Ash.Error.Invalid, fn
               %Ash.Error.Changes.InvalidArgument{
                 field: :invitation_code,
                 message: "The invitation has already been used"
               } ->
                 true

               _ ->
                 false
             end)
    end

    test "users can't register with an expired invitation code", %{admin: admin, club: club} do
      invitation_code =
        generate(invitation_code(actor: admin, club_ids: [club.id]))
        |> Ash.Seed.update!(%{expires_at: DateTime.utc_now() |> DateTime.add(-10, :day)})

      assert register_with_password(%{
               username: "nate",
               password: "passw0rd",
               password_confirmation: "passw0rd",
               invitation_code: invitation_code.code,
               locale: :en_US
             })
             |> assert_has_error(Ash.Error.Invalid, fn
               %Ash.Error.Changes.InvalidArgument{
                 field: :invitation_code,
                 message: "The invitation has expired"
               } ->
                 true

               _ ->
                 false
             end)
    end

    test "users can't register with an invitation code that does not exist" do
      assert register_with_password(%{
               username: "nate",
               password: "passw0rd",
               password_confirmation: "passw0rd",
               invitation_code: "DOES_NOT_EXIST",
               locale: :en_US
             })
             |> assert_has_error(Ash.Error.Invalid, fn
               %Ash.Error.Changes.InvalidArgument{
                 field: :invitation_code,
                 message: "The invitation code is not valid"
               } ->
                 true

               _ ->
                 false
             end)
    end

    test "fails when the password does not match", %{admin: admin, club: club} do
      invitation_code = generate(invitation_code(actor: admin, club_ids: [club.id]))

      assert register_with_password(%{
               username: "nate",
               password: "passw0rd",
               password_confirmation: "wrongpassword",
               invitation_code: invitation_code.code,
               locale: :en_US
             })
             |> assert_has_error(Ash.Error.Invalid, fn
               %Ash.Error.Changes.InvalidArgument{field: :password_confirmation} -> true
               _ -> false
             end)
    end

    test "fails with an invalid locale", %{admin: admin, club: club} do
      invitation_code = generate(invitation_code(actor: admin, club_ids: [club.id]))

      register_with_password(%{
        username: "nate",
        password: "passw0rd",
        password_confirmation: "passw0rd",
        invitation_code: invitation_code.code,
        locale: :it_IT
      })
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidArgument{field: :locale} -> true
        _ -> false
      end)
    end
  end

  describe "destroy_user/*" do
    setup do
      admin = generate(administrator())
      club = generate(club(actor: admin))
      member = generate(user())
      membership = generate(membership(club, member, role: :member))

      {:ok, admin: admin, club: club, member: member, membership: membership}
    end

    test "the administrator can delete a user and their memberships", %{
      admin: admin,
      member: member,
      membership: membership
    } do
      assert :ok = destroy_user!(member, actor: admin)

      assert Ash.get(User, member.id, authorize?: false) |> elem(0) == :error
      assert Ash.get(Membership, membership.id, authorize?: false) |> elem(0) == :error
    end

    test "deleting a user sends a clubs::<club_id> pubsub event for their memberships", %{
      admin: admin,
      club: club,
      member: member,
      membership: membership
    } do
      topic = "clubs:#{club.id}:memberships"
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, topic)
      assert :ok = destroy_user!(member, actor: admin)

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

    test "only the administrator can delete users", %{member: member} do
      other_user = generate(user())

      assert destroy_user(member, actor: other_user)
             |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "the administrator account cannot be deleted", %{admin: admin} do
      assert destroy_user(admin, actor: admin)
             |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end
end
