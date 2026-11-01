defmodule WatchClub.Clubs.LibraryItemTest do
  use WatchClub.DataCase

  import WatchClub.Clubs

  alias WatchClub.Clubs.LibraryItem
  alias WatchClub.Contents.{Content, ContentIdentity}

  require Ash.Query

  setup do
    admin = generate(administrator())
    club = generate(club(actor: admin))
    # Add a member
    member = generate(user())
    membership = generate(membership(club, member, role: :member))

    {:ok, admin: admin, club: club, member: member, membership: membership}
  end

  describe "add_content_to_libraries/*" do
    test "adds the content to the libraries", %{club: club, admin: admin, member: member} do
      library = generate(library(club, content_type: :movie))
      content = generate(movie(actor: admin))

      assert %Content{} =
               add_content_to_libraries!(identity(content), [library.id], actor: member)

      assert library_item(content, library).added_by_id == member.id
    end

    test "rejects libraries that do not allow the content type", %{
      club: club,
      admin: admin,
      member: member
    } do
      library = generate(library(club, name: "Books", content_type: :book))
      content = generate(movie(actor: admin))

      assert_raise Ash.Error.Invalid, ~r/Library does not allow this content type/, fn ->
        add_content_to_libraries(identity(content), [library.id], actor: member)
      end
    end

    test "requires membership in the libraries", %{club: club, admin: admin} do
      library = generate(library(club, content_type: :movie))
      content = generate(movie(actor: admin))
      non_member = generate(user())

      assert_raise Ash.Error.Forbidden, fn ->
        add_content_to_libraries(identity(content), [library.id], actor: non_member)
      end
    end
  end

  describe "remove_content_from_libraries/*" do
    test "removes library items added by the actor", %{club: club, member: member} do
      library = generate(library(club, content_type: :movie))
      content = content_in_libraries([library], member)

      assert %Content{} =
               remove_content_from_libraries!(identity(content), [library.id], actor: member)

      refute library_item(content, library)
    end

    test "does not remove library items from clubs the actor cannot access", %{
      club: club,
      admin: admin,
      member: member
    } do
      member_library = generate(library(club, content_type: :movie))
      other_club = generate(club(actor: admin))
      other_library = generate(library(other_club, content_type: :movie))
      content = content_in_libraries([member_library, other_library], admin)

      remove_content_from_libraries!(identity(content), [other_library.id], actor: member)

      assert library_item(content, other_library)
    end

    test "forbids removing library items the actor can access but did not add", %{
      club: club,
      admin: admin,
      member: member
    } do
      library = generate(library(club, content_type: :movie))
      content = content_in_libraries([library], admin)

      assert_raise Ash.Error.Forbidden, fn ->
        remove_content_from_libraries!(identity(content), [library.id], actor: member)
      end

      assert library_item(content, library).added_by_id == admin.id
    end

    test "preserves library items added by a former member", %{
      club: club,
      member: member,
      membership: membership
    } do
      library = generate(library(club, content_type: :movie))
      content = content_in_libraries([library], member)

      leave_club!(membership, actor: member)

      remove_content_from_libraries!(identity(content), [library.id], actor: member)

      assert library_item(content, library).added_by_id == member.id
    end

    test "allows a rejoined member to remove library items they added before leaving", %{
      club: club,
      member: member,
      membership: membership
    } do
      library = generate(library(club, content_type: :movie))
      content = content_in_libraries([library], member)

      leave_club!(membership, actor: member)
      generate(membership(club, member, role: :member))

      remove_content_from_libraries!(identity(content), [library.id], actor: member)

      refute library_item(content, library)
    end

    test "only club admins can remove orphaned library items", %{
      club: club,
      admin: admin,
      member: member
    } do
      library = generate(library(club, content_type: :movie))
      content = content_in_libraries([library], member)

      content |> library_item(library) |> Ash.Seed.update!(%{added_by_id: nil})

      assert_raise Ash.Error.Forbidden, fn ->
        remove_content_from_libraries!(identity(content), [library.id], actor: member)
      end

      assert library_item(content, library)

      remove_content_from_libraries!(identity(content), [library.id], actor: admin)

      refute library_item(content, library)
    end
  end

  defp content_in_libraries(libraries, actor) do
    content = generate(movie())
    add_content_to_libraries!(identity(content), Enum.map(libraries, & &1.id), actor: actor)
    content
  end

  defp identity(%Content{} = content), do: ContentIdentity.from_content(content)

  defp library_item(%Content{id: content_id}, %{id: library_id}) do
    LibraryItem
    |> Ash.Query.filter(content_id == ^content_id and library_id == ^library_id)
    |> Ash.read_one!(authorize?: false)
  end
end
