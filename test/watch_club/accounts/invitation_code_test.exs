defmodule WatchClub.Accounts.InvitationCodeTest do
  use WatchClub.DataCase

  import WatchClub.Accounts

  alias WatchClub.Accounts.InvitationCode

  setup do
    admin = generate(administrator())
    member = generate(user())

    {:ok, admin: admin, member: member}
  end

  describe "create_invitation_code/*" do
    test "creates an invitation code", %{admin: admin} do
      assert %InvitationCode{
               code: "FAMILY_2026",
               max_uses: 5,
               uses: 0,
               expires_at: %DateTime{} = expires_at
             } =
               invitation_code =
               create_invitation_code!(
                 %{code: "FAMILY_2026", max_uses: 5},
                 actor: admin
               )

      assert DateTime.after?(expires_at, DateTime.add(DateTime.utc_now(), 6, :day))

      assert %InvitationCode{status: :active} =
               Ash.load!(invitation_code, :status, actor: admin)
    end

    test "only the instance administrator can create invitation codes", %{
      member: member
    } do
      create_invitation_code(%{code: "NOT_ALLOWED"}, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "update_invitation_code/*" do
    test "it can modify the max number of uses", %{
      admin: admin
    } do
      invitation_code =
        create_invitation_code!(%{code: "OPEN_HOUSE"}, actor: admin)

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
    test "anyone with the code can view the invitation", %{
      admin: admin
    } do
      generate(invitation_code(actor: admin, code: "WELCOME"))

      assert %InvitationCode{status: :active} =
               view_invitation!("WELCOME")
    end
  end
end
