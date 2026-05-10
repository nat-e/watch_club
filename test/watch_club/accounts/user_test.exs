defmodule WatchClub.Accounts.UserTest do
  use WatchClub.DataCase

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.{Invitation, Membership}

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
    setup do
      admin = generate(administrator())
      club = generate(club(actor: admin))
      invitation = generate(invitation(club, admin))

      {:ok, admin: admin, club: club, invitation: invitation}
    end

    test "signs the user in with their username and password" do
      password = "passw0rd"
      user = generate(user(password: password, password_confirmation: password))
      user_id = user.id

      assert %User{id: ^user_id} = sign_in!(%{username: user.username, password: password})
    end

    test "signs the user with an invitation accepts it", %{club: club, admin: admin} do
      password = "passw0rd"
      invitation = generate(invitation(club, admin))

      user = generate(user(password: password, password_confirmation: password))

      assert %User{} =
               sign_in!(%{
                 username: user.username,
                 password: password,
                 invitation_id: invitation.id
               })

      user_id = user.id

      assert %Invitation{
               accepted?: true,
               created_membership: %Membership{
                 user_id: ^user_id
               }
             } =
               WatchClub.Clubs.view_invitation!(invitation.id,
                 load: :created_membership,
                 authorize?: false
               )
    end

    test "users can't signin with an already accepted? invitation", %{admin: admin, club: club} do
      password = "passw0rd"

      invitation =
        generate(invitation(club, admin))
        |> Ash.Seed.update!(%{accepted?: true})

      user = generate(user(password: password, password_confirmation: password))

      assert sign_in(%{
               username: user.username,
               password: password,
               invitation_id: invitation.id
             })
             |> assert_has_error(Ash.Error.Invalid, fn
               %Ash.Error.Query.InvalidArgument{
                 field: :invitation_id,
                 message: "The invitation has already been used"
               } ->
                 true

               _ ->
                 false
             end)
    end

    test "users can't signin with an expired invitation", %{admin: admin, club: club} do
      password = "passw0rd"

      invitation =
        generate(invitation(club, admin))
        |> Ash.Seed.update!(%{expires_at: DateTime.utc_now() |> DateTime.add(-10, :day)})

      user = generate(user(password: password, password_confirmation: password))

      assert sign_in(%{
               username: user.username,
               password: password,
               invitation_id: invitation.id
             })
             |> assert_has_error(Ash.Error.Invalid, fn
               %Ash.Error.Query.InvalidArgument{
                 field: :invitation_id,
                 message: "The invitation has expired"
               } ->
                 true

               _ ->
                 false
             end)
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

    test "fails when the password is incorrect with an invitation", %{admin: admin, club: club} do
      user = generate(user())
      invitation = generate(invitation(club, admin))

      assert_raise Ash.Error.Forbidden, fn ->
        sign_in!(%{
          username: user.username,
          password: "wrongpassword",
          invitation_id: invitation.id
        })
      end
    end
  end

  describe "register_with_password/*" do
    setup do
      admin = generate(administrator())
      club = generate(club(actor: admin))
      invitation = generate(invitation(club, admin))

      {:ok, admin: admin, club: club, invitation: invitation}
    end

    test "users can register with an invitation code", %{invitation: invitation} do
      assert %User{settings: %{locale: :en_US}} =
               user =
               register_with_password!(%{
                 username: "nate",
                 password: "passw0rd",
                 password_confirmation: "passw0rd",
                 invitation_id: invitation.id,
                 locale: :en_US
               })

      user_id = user.id

      assert %Invitation{
               accepted?: true,
               created_membership: %Membership{
                 user_id: ^user_id
               }
             } =
               WatchClub.Clubs.view_invitation!(invitation.id,
                 load: :created_membership,
                 authorize?: false
               )
    end

    test "users can't register without invitation" do
      assert register_with_password(%{
               username: "nate",
               password: "passw0rd",
               password_confirmation: "passw0rd"
             })
             |> assert_has_error(Ash.Error.Invalid, fn
               %Ash.Error.Changes.Required{
                 field: :invitation_id
               } ->
                 true

               _ ->
                 false
             end)
    end

    test "users can't register with an already accepted? invitation", %{admin: admin, club: club} do
      invitation =
        generate(invitation(club, admin))
        |> Ash.Seed.update!(%{accepted?: true})

      assert register_with_password(%{
               username: "nate",
               password: "passw0rd",
               password_confirmation: "passw0rd",
               invitation_id: invitation.id,
               locale: :en_US
             })
             |> assert_has_error(Ash.Error.Invalid, fn
               %Ash.Error.Changes.InvalidArgument{
                 field: :invitation_id,
                 message: "The invitation has already been used"
               } ->
                 true

               _ ->
                 false
             end)
    end

    test "users can't register with an expired invitation", %{admin: admin, club: club} do
      invitation =
        generate(invitation(club, admin))
        |> Ash.Seed.update!(%{expires_at: DateTime.utc_now() |> DateTime.add(-10, :day)})

      assert register_with_password(%{
               username: "nate",
               password: "passw0rd",
               password_confirmation: "passw0rd",
               invitation_id: invitation.id,
               locale: :en_US
             })
             |> assert_has_error(Ash.Error.Invalid, fn
               %Ash.Error.Changes.InvalidArgument{
                 field: :invitation_id,
                 message: "The invitation has expired"
               } ->
                 true

               _ ->
                 false
             end)
    end

    test "fails when the password does not match", %{invitation: invitation} do
      assert register_with_password(%{
               username: "nate",
               password: "passw0rd",
               password_confirmation: "wrongpassword",
               invitation_id: invitation.id,
               locale: :en_US
             })
             |> assert_has_error(Ash.Error.Invalid, fn
               %Ash.Error.Changes.InvalidArgument{field: :password_confirmation} -> true
               _ -> false
             end)
    end

    test "fails with an invalid locale", %{invitation: invitation} do
      register_with_password(%{
        username: "nate",
        password: "passw0rd",
        password_confirmation: "passw0rd",
        invitation_id: invitation.id,
        locale: :it_IT
      })
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidArgument{field: :locale} -> true
        _ -> false
      end)
    end
  end
end
