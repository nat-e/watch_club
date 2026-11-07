defmodule WatchClub.Accounts.UserTest do
  use WatchClub.DataCase

  alias WatchClub.Accounts.{InvitationCode, User}
  alias WatchClub.Playlists
  alias WatchClub.Playlists.{Playlist, PlaylistItem}
  alias WatchClub.Requests.ContentRequest

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

      {:ok, admin: admin}
    end

    test "registering uses the invitation code", %{
      admin: admin
    } do
      invitation_code =
        generate(invitation_code(actor: admin))

      assert %User{settings: %{locale: :en_US}} =
               register_with_password!(%{
                 username: "nate",
                 password: "passw0rd",
                 password_confirmation: "passw0rd",
                 invitation_code: invitation_code.code,
                 locale: :en_US
               })

      assert %InvitationCode{uses: 1} =
               Ash.get!(InvitationCode, invitation_code.id, authorize?: false)
    end

    test "a new user starts with a To Watch playlist, named in their locale", %{admin: admin} do
      invitation_code = generate(invitation_code(actor: admin))

      user =
        register_with_password!(%{
          username: "nate",
          password: "passw0rd",
          password_confirmation: "passw0rd",
          invitation_code: invitation_code.code,
          locale: :fr_FR
        })

      assert [%Playlist{name: "À voir", icon: "popcorn"}] = Playlists.list_playlists!(actor: user)
    end

    test "users can't register without an invitation code" do
      assert register_with_password(%{
               username: "nate",
               password: "passw0rd",
               password_confirmation: "passw0rd"
             })
             |> assert_has_error(Ash.Error.Invalid, fn
               %Ash.Error.Changes.InvalidAttribute{
                 field: :invitation_code
               } ->
                 true

               _ ->
                 false
             end)
    end

    test "users can't register with a used invitation code", %{admin: admin} do
      invitation_code =
        generate(invitation_code(actor: admin, max_uses: 1))
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

    test "users can't register with an expired invitation code", %{admin: admin} do
      invitation_code =
        generate(invitation_code(actor: admin))
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

    test "fails when the password does not match", %{admin: admin} do
      invitation_code = generate(invitation_code(actor: admin))

      assert register_with_password(%{
               username: "nate",
               password: "passw0rd",
               password_confirmation: "wrongpassword",
               invitation_code: invitation_code.code,
               locale: :en_US
             })
             |> assert_has_error(Ash.Error.Invalid, fn
               %Ash.Error.Changes.InvalidAttribute{field: :password_confirmation} -> true
               _ -> false
             end)
    end

    test "fails with an invalid locale", %{admin: admin} do
      invitation_code = generate(invitation_code(actor: admin))

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
      member = generate(user())

      {:ok, admin: admin, member: member}
    end

    test "the administrator can delete a user", %{
      admin: admin,
      member: member
    } do
      assert :ok = destroy_user!(member, actor: admin)

      assert Ash.get(User, member.id, authorize?: false) |> elem(0) == :error
    end

    test "keeps the user's Content Requests, as from a deleted User", %{
      admin: admin,
      member: member
    } do
      request = generate(content_request(member, generate(movie())))

      assert :ok = destroy_user!(member, actor: admin)

      assert %ContentRequest{requested_by_id: nil} =
               Ash.get!(ContentRequest, request.id, authorize?: false)
    end

    test "a deleted user's Messages and place in Conversations stay", %{
      admin: admin,
      member: member
    } do
      friend = generate(user())
      conversation = generate(conversation(member, generate(movie()), [friend]))
      generate(message(conversation, member))

      assert :ok = destroy_user!(member, actor: admin)

      assert %{recommended_by_id: nil, participants: participants, messages: messages} =
               WatchClub.Conversations.get_conversation!(conversation.id,
                 load: [:participants, :messages],
                 actor: friend
               )

      assert participants |> Enum.map(& &1.user_id) |> Enum.sort() == Enum.sort([nil, friend.id])
      assert Enum.map(messages, & &1.author_id) == [nil, nil]
    end

    test "the content a deleted user added stays in the playlists shared with them", %{
      admin: admin,
      member: member
    } do
      owner = generate(user())
      playlist = generate(playlist(owner))
      generate(playlist_access(playlist, member, :edit))
      generate(playlist_item(playlist, generate(movie()), added_by_id: member.id))

      destroy_user!(member, actor: admin)

      assert [%PlaylistItem{added_by_id: nil}] =
               Playlists.list_playlist_items!(playlist.id, actor: owner)
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
