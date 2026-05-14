defmodule WatchClub.Clubs.LibraryTest do
  use WatchClub.DataCase

  import WatchClub.Clubs

  alias WatchClub.Clubs.Library

  require Ash.Query

  setup do
    admin = generate(administrator())
    club = generate(club(actor: admin))
    member = generate(user())
    generate(membership(club, member, role: :member))

    {:ok, admin: admin, club: club, member: member}
  end

  describe "create_library/*" do
    test "creates a library", %{club: club, admin: admin} do
      generate(library(club, index: 0))
      generate(library(club, index: 1))
      club_id = club.id

      assert %Library{
               club_id: ^club_id,
               content_type: :movie,
               name: "Movies",
               index: 2
             } = create_library!(club.id, %{content_type: :movie, name: "Movies"}, actor: admin)
    end

    test "members cannot create libraries", %{club: club, member: member} do
      create_library(club.id, %{content_type: :movie, name: "Movies"}, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "list_club_libraries/*" do
    test "lists club libraries by index", %{club: club, member: member} do
      generate(library(club, name: "Third", index: 2))
      generate(library(club, name: "First", index: 0))
      generate(library(club, name: "Second", index: 1))

      libraries = list_club_libraries!(club.id, actor: member)

      assert ["First", "Second", "Third"] = Enum.map(libraries, & &1.name)
    end

    test "non-members cannot list libraries", %{club: club} do
      generate(library(club))
      non_member = generate(user())

      list_club_libraries(club.id, actor: non_member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "update_library/*" do
    test "admins can rename libraries", %{club: club, admin: admin} do
      library = generate(library(club))

      assert %Library{name: "Films"} = update_library!(library, %{name: "Films"}, actor: admin)
    end

    test "members cannot rename libraries", %{club: club, member: member} do
      library = generate(library(club))

      update_library(library, %{name: "Films"}, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "destroy_library/*" do
    test "admins can destroy libraries", %{club: club, admin: admin} do
      library = generate(library(club))

      assert :ok = destroy_library!(library, actor: admin)
    end

    test "recomputes indexes of remaining libraries", %{club: club, admin: admin} do
      _first = generate(library(club, index: 0, name: "First"))
      second = generate(library(club, index: 1, name: "Second"))
      _third = generate(library(club, index: 2, name: "Third"))

      assert :ok = destroy_library!(second, actor: admin)

      assert [
               %Library{name: "First", index: 0},
               %Library{name: "Third", index: 1}
             ] =
               Library
               |> Ash.Query.filter(club_id == ^club.id)
               |> Ash.Query.sort(index: :asc)
               |> Ash.read!(authorize?: false)
    end

    test "members cannot destroy libraries", %{club: club, member: member} do
      library = generate(library(club))

      destroy_library(library, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end
end
