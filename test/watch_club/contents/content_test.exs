defmodule WatchClub.Clubs.ContentTest do
  use WatchClub.DataCase

  import WatchClub.Contents

  alias WatchClub.Accounts
  alias WatchClub.Clubs.LibraryItem
  alias WatchClub.Contents.{Content, Movie, MovieLocalization}

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
    test "creates a movie", %{admin: admin} do
      settings = Accounts.update_user_settings!(admin.settings, %{locale: :fr_FR}, actor: admin)
      actor = %{admin | settings: settings}

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
               |> Ash.read!(authorize?: false)

      assert %Content{localized_title_key: "la guerre des etoiles"} =
               Content
               |> Ash.Query.filter(id == ^content.id)
               |> Ash.Query.load(:localized_title_key)
               |> Ash.read_one!(actor: actor, authorize?: false)
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
