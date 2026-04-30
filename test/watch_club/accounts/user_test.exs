defmodule WatchClub.Accounts.UserTest do
  alias WatchClub.Accounts.User
  use WatchClub.DataCase

  import WatchClub.Accounts

  describe "create_administrator/*" do
    test "creates the administrator if there are none" do
      assert %User{administrator?: true} =
               create_administrator!(%{
                 email: "su@test.com",
                 username: "nate",
                 password: "passw0rd",
                 password_confirmation: "passw0rd"
               })
    end

    test "fails if there is already a administrator" do
      generate(administrator())

      create_administrator(%{
        email: "su@test.com",
        username: "nate",
        password: "passw0rd",
        password_confirmation: "passw0rd"
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
end
