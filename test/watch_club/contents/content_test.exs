defmodule WatchClub.Clubs.ContentTest do
  use WatchClub.DataCase

  import ExUnit.CaptureLog
  import WatchClub.Contents

  alias WatchClub.Clubs.LibraryItem
  alias WatchClub.Contents.{Content, ContentView, Movie, MovieLocalization}

  require Ash.Query

  setup do
    admin = generate(administrator())
    club = generate(club(actor: admin))
    # Add a member
    member = generate(user())
    generate(membership(club, member, role: :member))

    Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
      tmdb_id = conn.request_path |> Path.basename() |> String.to_integer()
      Req.Test.json(conn, Map.put(tmdb_fixture("movie_details_11"), "id", tmdb_id))
    end)

    {:ok, admin: admin, club: club, member: member}
  end

  describe "create_movie/*" do
    test "creates a movie" do
      actor = generate(user(locale: :fr_FR))

      assert %Content{
               type: :movie,
               external_id_source: :tmdb,
               external_id: "11",
               original_language: "en",
               origin_country: "US",
               implementation: %Movie{
                 best_localization: %MovieLocalization{
                   iso_639_1: "fr",
                   iso_3166_1: "FR",
                   title: "La Guerre des étoiles"
                 }
               }
             } = content = create_movie!("11", actor: actor)

      assert [
               %MovieLocalization{iso_639_1: "en", iso_3166_1: "US"},
               %MovieLocalization{iso_639_1: "fr", iso_3166_1: "FR"}
             ] =
               MovieLocalization
               |> Ash.Query.filter(movie_id == ^content.id)
               |> Ash.Query.sort(iso_639_1: :asc)
               |> Ash.read!(actor: actor, authorize?: false)

      assert %Content{localized_title_key: "la guerre des etoiles"} =
               Content
               |> Ash.Query.filter(id == ^content.id)
               |> Ash.Query.load(:localized_title_key)
               |> Ash.read_one!(actor: actor, authorize?: false)
    end

    test "returns an invalid error when TMDB fetch fails" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"status_message" => "Not found"})
      end)

      capture_log(fn ->
        create_movie("404", actor: generate(user()))
        |> assert_has_error(Ash.Error.Invalid, fn
          %Ash.Error.Changes.InvalidChanges{message: "Failed to fetch movie from TMDB"} -> true
          _ -> false
        end)
      end)
    end

    test "creates a movie when optional TMDB details are missing" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        tmdb_id = conn.request_path |> Path.basename() |> String.to_integer()

        response =
          "movie_details_11"
          |> tmdb_fixture()
          |> Map.merge(%{
            "id" => tmdb_id,
            "images" => nil,
            "origin_country" => ["CA"],
            "production_countries" => [],
            "translations" => %{"translations" => []}
          })

        Req.Test.json(conn, response)
      end)

      assert %Content{
               origin_country: "CA",
               implementation: %Movie{
                 best_localization: %MovieLocalization{title: "Star Wars"}
               }
             } = create_movie!("12", actor: generate(user()))
    end

    test "requires membership in selected libraries", %{club: club} do
      library = generate(library(club, accepted_content_types: [:movie]))
      non_member = generate(user())

      create_movie("13", %{library_ids: [library.id]}, actor: non_member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "search_content/*" do
    test "attaches existing TMDB content to matching search results", %{
      club: club,
      admin: admin,
      member: member
    } do
      library = generate(library(club, accepted_content_types: [:movie]))
      library_id = library.id
      content = create_movie!("11", %{library_ids: [library.id]}, actor: admin)
      content_id = content.id

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Req.Test.json(conn, %{
          "results" => [%{"id" => 11, "media_type" => "movie", "title" => "Star Wars"}]
        })
      end)

      assert [
               %ContentView{
                 content: %Content{id: ^content_id},
                 external_id: "11",
                 in_libraries: [%LibraryItem{library_id: ^library_id}]
               }
             ] = search_content!(%{query: "star", content_type: :movies_and_shows}, actor: member)
    end
  end

  describe "set_club_libraries/*" do
    test "adds content to selected club libraries", %{club: club, admin: admin, member: member} do
      library = generate(library(club, accepted_content_types: [:movie]))
      library_id = library.id
      content = generate(movie(actor: admin))

      assert %Content{library_items: [%LibraryItem{library_id: ^library_id} = item]} =
               set_club_libraries!(content, %{library_ids: [library.id]}, actor: member)

      assert item.library.club_id == club.id
    end

    test "rejects selected club libraries that do not accept the content type", %{
      club: club,
      admin: admin,
      member: member
    } do
      library = generate(library(club, accepted_content_types: [:book]))
      content = generate(movie(actor: admin))

      set_club_libraries(content, %{library_ids: [library.id]}, actor: member)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidChanges{
          message: "Library does not accept this content type"
        } ->
          true

        _ ->
          false
      end)
    end

    test "requires membership in selected libraries", %{club: club, admin: admin} do
      library = generate(library(club, accepted_content_types: [:movie]))
      content = generate(movie(actor: admin))
      non_member = generate(user())

      set_club_libraries(content, %{library_ids: [library.id]}, actor: non_member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end
end
