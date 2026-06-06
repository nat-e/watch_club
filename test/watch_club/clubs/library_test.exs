defmodule WatchClub.Clubs.LibraryTest do
  use WatchClub.DataCase

  import WatchClub.Clubs

  alias WatchClub.Clubs.Library
  alias WatchClub.Contents.ContentView

  require Ash.Query

  @library_sort_movies [
    %{
      tmdb_id: 101,
      original_title: "ZZZ Original",
      title: "Zulu",
      release_date: "2020-01-01",
      translations: [{"en", "US", "Zulu"}, {"fr", "FR", "Abricot"}]
    },
    %{
      tmdb_id: 102,
      original_title: "YYY Original",
      title: "Banana",
      release_date: "2021-01-01",
      translations: [{"en", "US", "Banana"}, {"fr", "FR", "Banana"}]
    },
    %{
      tmdb_id: 103,
      original_title: "XXX Original",
      title: "Alpha",
      release_date: "2022-01-01",
      translations: [{"en", "US", "Alpha"}, {"fr", "FR", "Cerise"}]
    },
    %{
      tmdb_id: 104,
      original_title: "WWW Original",
      title: "Dattel",
      release_date: "2023-01-01",
      translations: [{"en", "US", "Dattel"}, {"fr", "FR", "Dattel"}]
    },
    %{
      tmdb_id: 105,
      original_title: "VVV Original",
      title: "Eclair",
      release_date: "2024-01-01",
      translations: [{"en", "US", "Eclair"}, {"fr", "FR", "Éclair"}]
    },
    %{
      tmdb_id: 106,
      original_title: "UUU Original",
      title: "Eden",
      release_date: "2025-01-01",
      translations: [{"en", "US", "Eden"}, {"fr", "FR", "Eden"}]
    }
  ]

  setup do
    admin = generate(administrator())
    club = generate(club(actor: admin))
    member = generate(user())
    generate(membership(club, member, role: :member))

    Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
      tmdb_id = conn.request_path |> Path.basename() |> String.to_integer()

      details =
        Enum.find(@library_sort_movies, &(&1.tmdb_id == tmdb_id)) ||
          %{
            original_title: "Movie #{tmdb_id}",
            title: "Movie #{tmdb_id}",
            release_date: "2020-01-01",
            translations: [{"en", "US", "Movie #{tmdb_id}"}, {"fr", "FR", "Film #{tmdb_id}"}]
          }

      translations =
        Enum.map(details.translations, fn {iso_639_1, iso_3166_1, title} ->
          %{
            "iso_639_1" => iso_639_1,
            "iso_3166_1" => iso_3166_1,
            "name" => title,
            "english_name" => title,
            "data" => %{"title" => title}
          }
        end)

      response =
        "movie_details_11"
        |> tmdb_fixture()
        |> Map.merge(%{
          "id" => tmdb_id,
          "original_title" => details.original_title,
          "title" => details.title,
          "release_date" => details.release_date,
          "translations" => %{"translations" => translations}
        })

      Req.Test.json(conn, response)
    end)

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
               icon: "film",
               name: "Movies",
               index: 2
             } =
               create_library!(club.id, %{content_type: :movie, name: "Movies"}, actor: admin)
    end

    test "sets the default icon from the content type", %{club: club, admin: admin} do
      assert %Library{content_type: :book, icon: "book_open"} =
               create_library!(club.id, %{content_type: :book, name: "Books"}, actor: admin)
    end

    test "allows multiple libraries with the same content type", %{club: club, admin: admin} do
      assert %Library{content_type: :movie, name: "Candidates"} =
               create_library!(club.id, %{content_type: :movie, name: "Candidates"}, actor: admin)

      assert %Library{content_type: :movie, name: "Favorites"} =
               create_library!(club.id, %{content_type: :movie, name: "Favorites"}, actor: admin)
    end

    test "rejects missing content type", %{club: club, admin: admin} do
      create_library(club.id, %{name: "Movies"}, actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :content_type} -> true
        _ -> false
      end)
    end

    test "members cannot create libraries", %{club: club, member: member} do
      create_library(club.id, %{content_type: :movie, name: "Movies"}, actor: member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "get_library_items/*" do
    test "sorts items by localized title", %{club: club, admin: admin} do
      actor = generate(user(locale: :fr_FR))
      generate(membership(club, actor, role: :member))
      library = generate(library(club, content_type: :movie))

      Enum.each(@library_sort_movies, fn movie_details ->
        generate(movie(tmdb_id: movie_details.tmdb_id, library_ids: [library.id], actor: admin))
      end)

      items = get_library_items!(library.id, %{sort_by: :title, sort_order: :asc}, actor: actor)

      assert ["Abricot", "Banana", "Cerise", "Dattel", "Éclair", "Eden"] =
               Enum.map(items, fn item ->
                 item.content
                 |> ContentView.from_content()
                 |> Map.fetch!(:title)
               end)
    end

    test "paginates items with keysets", %{club: club, admin: admin} do
      library = generate(library(club, content_type: :movie))

      Enum.each([203, 201, 202], fn tmdb_id ->
        generate(movie(tmdb_id: tmdb_id, library_ids: [library.id], actor: admin))
      end)

      first_page =
        get_library_items!(library.id, %{sort_by: :title, sort_order: :asc},
          actor: admin,
          page: [limit: 2]
        )

      assert %Ash.Page.Keyset{results: first_items, more?: true} = first_page

      assert ["Movie 201", "Movie 202"] =
               Enum.map(first_items, fn item ->
                 item.content
                 |> ContentView.from_content()
                 |> Map.fetch!(:title)
               end)

      second_page =
        get_library_items!(library.id, %{sort_by: :title, sort_order: :asc},
          actor: admin,
          page: [limit: 2, after: List.last(first_items).__metadata__.keyset]
        )

      assert %Ash.Page.Keyset{results: second_items, more?: false} = second_page

      assert ["Movie 203"] =
               Enum.map(second_items, fn item ->
                 item.content
                 |> ContentView.from_content()
                 |> Map.fetch!(:title)
               end)
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
    test "admins can edit library name", %{club: club, admin: admin} do
      library = generate(library(club, content_type: :movie))

      assert %Library{name: "Screens", content_type: :movie} =
               update_library!(library, %{name: "Screens"}, actor: admin)
    end

    test "admins can update library icons", %{club: club, admin: admin} do
      library = generate(library(club))

      assert %Library{icon: "library"} =
               update_library!(library, %{icon: "library"}, actor: admin)
    end

    test "rejects invalid library icons", %{club: club, admin: admin} do
      library = generate(library(club))

      update_library(library, %{icon: "not_a_lucide_icon"}, actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :icon} -> true
        _ -> false
      end)
    end

    test "members cannot edit libraries", %{club: club, member: member} do
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
