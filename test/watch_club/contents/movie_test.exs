defmodule WatchClub.Clubs.MovieTest do
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
      assert %Movie{
               tmdb_id: 11,
               content: %Content{
                 type: :movie,
                 external_id_source: :tmdb,
                 external_id: "11",
                 original_language: "en",
                 origin_country: "US"
               },
               localizations: [_en, _fr]
             } = movie = create_movie!("11")

      IO.inspect(movie)
    end
  end
end
