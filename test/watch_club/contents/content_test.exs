defmodule WatchClub.Clubs.ContentTest do
  use WatchClub.DataCase

  import WatchClub.Contents

  alias WatchClub.Clubs.LibraryItem
  alias WatchClub.Contents.{Content, Movie, MovieLocalization}

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
      assert %Content{
               type: :movie,
               external_id_source: :tmdb,
               external_id: "11",
               original_language: "en",
               origin_country: "US",
               implementation: %Movie{
                 localizations: [
                   %MovieLocalization{iso_639_1: "en", iso_3166_1: "US"},
                   %MovieLocalization{iso_639_1: "fr", iso_3166_1: "FR"}
                 ]
               }
             } = create_movie!("11")
    end
  end

  describe "set_club_libraries/*" do
    test "adds content to selected club libraries", %{club: club, member: member} do
      library = generate(library(club, content_type: :movie))
      library_id = library.id
      content = generate(movie())

      assert %Content{library_items: [%LibraryItem{library_id: ^library_id} = item]} =
               set_club_libraries!(content, %{library_ids: [library.id]}, actor: member)

      assert item.library.club_id == club.id
    end
  end
end
