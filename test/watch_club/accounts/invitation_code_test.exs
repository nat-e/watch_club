defmodule WatchClub.Accounts.InvitationCodeTest do
  use WatchClub.DataCase

  import WatchClub.Accounts

  alias WatchClub.Accounts.InvitationCode
  alias WatchClub.Clubs.Club

  setup do
    admin = generate(administrator())
    club = generate(club(actor: admin))
    member = generate(user())
    generate(membership(club, member, role: :member))

    {:ok, admin: admin, club: club, member: member}
  end

  describe "create_invitation_code/*" do
    test "creates an invitation code granting access to clubs", %{admin: admin, club: club} do
      club_id = club.id

      assert %InvitationCode{
               code: "FAMILY_2026",
               max_uses: 5,
               uses: 0,
               expires_at: %DateTime{} = expires_at
             } =
               invitation_code =
               create_invitation_code!(
                 %{code: "FAMILY_2026", max_uses: 5, club_ids: [club.id]},
                 actor: admin
               )

      assert DateTime.after?(expires_at, DateTime.add(DateTime.utc_now(), 6, :day))

      assert %InvitationCode{status: :active, clubs: [%Club{id: ^club_id}]} =
               Ash.load!(invitation_code, [:status, :clubs], actor: admin)
    end

    test "creates an invitation code not granting access to clubs", %{admin: admin} do
      invitation_code = create_invitation_code!(%{code: "OPEN_HOUSE", club_ids: []}, actor: admin)

      assert %InvitationCode{max_uses: nil, clubs: []} =
               Ash.load!(invitation_code, :clubs, actor: admin)
    end

    test "only the instance administrator can create invitation codes", %{
      member: member,
      club: club
    } do
      # A club admin is not enough: invitation codes are instance-wide
      create_invitation_code(%{code: "NOT_ALLOWED", club_ids: [club.id]}, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "update_invitation_code/*" do
    test "it can modify the list of clubs this invitation grants access to", %{
      admin: admin,
      club: club
    } do
      club2 = generate(club(actor: admin))

      invitation_code =
        create_invitation_code!(%{code: "OPEN_HOUSE", club_ids: [club.id]}, actor: admin)

      updated_club =
        update_invitation_code!(
          invitation_code,
          %{club_ids: [club2.id]},
          actor: admin
        )

      # The :update action loads :club_ids, so assert on the returned record.
      assert updated_club.club_ids == [club2.id]
    end

    test "it can modify the max number of uses", %{
      admin: admin,
      club: club
    } do
      invitation_code =
        create_invitation_code!(%{code: "OPEN_HOUSE", club_ids: [club.id]}, actor: admin)

      assert %InvitationCode{max_uses: 4} =
               update_invitation_code!(invitation_code, %{max_uses: 4}, actor: admin)
    end

    test "it cannot set the max number of uses lower than current uses", %{
      admin: admin
    } do
      invitation_code =
        create_invitation_code!(%{code: "OPEN_HOUSE", max_uses: 10}, actor: admin)
        |> Ash.Seed.update!(%{uses: 5})

      update_invitation_code(invitation_code, %{max_uses: 2}, actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{
          field: :max_uses
        } ->
          true

        _ ->
          false
      end)
    end

    test "only the instance administrator can update codes", %{
      member: member,
      admin: admin
    } do
      invitation_code =
        create_invitation_code!(%{code: "OPEN_HOUSE"}, actor: admin)

      # A club admin is not enough: invitation codes are instance-wide
      update_invitation_code(invitation_code, %{max_uses: 4}, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "delete_invitation_code/*" do
    test "deletes an invitation code", %{admin: admin} do
      invitation_code = generate(invitation_code(actor: admin))

      assert :ok = delete_invitation_code!(invitation_code, actor: admin)
      assert {:error, _} = Ash.get(InvitationCode, invitation_code.id, authorize?: false)
    end

    test "only the instance administrator can delete invitation codes", %{
      admin: admin,
      member: member
    } do
      invitation_code = generate(invitation_code(actor: admin))

      delete_invitation_code(invitation_code, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "view_invitation/*" do
    test "anyone with the code can view the invitation and its granted clubs", %{
      admin: admin,
      club: club
    } do
      generate(invitation_code(actor: admin, code: "WELCOME_CLUB", club_ids: [club.id]))
      club_id = club.id

      assert %InvitationCode{status: :active, clubs: [%Club{id: ^club_id}]} =
               view_invitation!("WELCOME_CLUB")
    end
  end
end
