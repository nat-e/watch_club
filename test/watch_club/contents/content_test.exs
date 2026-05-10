defmodule WatchClub.Clubs.ContentTest do
  use WatchClub.DataCase

  import WatchClub.Contents

  alias WatchClub.Contents.{Content, Movie, MovieLocalization}

  setup do
    admin = generate(administrator())
    club = generate(club(actor: admin))
    # Add a member
    member = generate(user())
    generate(membership(club, member, role: :member))

    Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
      Req.Test.json(conn, tmdb_fixture("movie_details_11"))
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
end
