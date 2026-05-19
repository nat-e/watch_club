defmodule WatchClub.Contents.ContentTest do
  use WatchClub.DataCase

  import ExUnit.CaptureLog
  import WatchClub.Clubs, only: [get_library_items!: 2, leave_club!: 2]
  import WatchClub.Contents

  alias WatchClub.Clubs.LibraryItem
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse

  alias WatchClub.Contents.{
    Content,
    ContentView,
    Movie,
    MovieLocalization,
    TvShow,
    TvShowEpisode,
    TvShowLocalization
  }

  require Ash.Query

  setup do
    admin = generate(administrator())
    club = generate(club(actor: admin))
    # Add a member
    member = generate(user())
    membership = generate(membership(club, member, role: :member))

    Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
      tmdb_id = conn.request_path |> Path.basename() |> String.to_integer()
      Req.Test.json(conn, Map.put(tmdb_fixture("movie_details_11"), "id", tmdb_id))
    end)

    {:ok, admin: admin, club: club, member: member, membership: membership}
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
      library = generate(library(club, content_type: :movie))
      non_member = generate(user())

      create_movie("13", %{library_ids: [library.id]}, actor: non_member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "create_tv_show/*" do
    test "creates a TV show with all available episodes" do
      actor = generate(user(locale: :fr_FR))

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        tmdb_id = conn.request_path |> Path.basename() |> String.to_integer()
        Req.Test.json(conn, Map.put(tv_details_fixture(), "id", tmdb_id))
      end)

      assert %Content{
               type: :tv_show,
               external_id_source: :tmdb,
               external_id: "42",
               original_title: "The Expanse",
               original_language: "en",
               origin_country: "US",
               release_date: ~D[2015-12-14],
               implementation: %TvShow{
                 best_localization: %TvShowLocalization{
                   iso_639_1: "fr",
                   iso_3166_1: "FR",
                   title: "The Expanse FR"
                 }
               }
             } = content = create_tv_show!("42", actor: actor)

      assert [
               %TvShowEpisode{season_number: 1, episode_number: 1},
               %TvShowEpisode{season_number: 1, episode_number: 2},
               %TvShowEpisode{season_number: 1, episode_number: 3},
               %TvShowEpisode{season_number: 2, episode_number: 1},
               %TvShowEpisode{season_number: 2, episode_number: 2}
             ] =
               TvShowEpisode
               |> Ash.Query.filter(tv_show_id == ^content.id)
               |> Ash.Query.sort(season_number: :asc, episode_number: :asc)
               |> Ash.read!(actor: actor, authorize?: false)
    end

    test "returns an invalid error when TMDB fetch fails" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"status_message" => "Not found"})
      end)

      capture_log(fn ->
        create_tv_show("404", actor: generate(user()))
        |> assert_has_error(Ash.Error.Invalid, fn
          %Ash.Error.Changes.InvalidChanges{message: "Failed to fetch TV show from TMDB"} ->
            true

          _ ->
            false
        end)
      end)
    end

    test "requires membership in selected libraries", %{club: club} do
      library = generate(library(club, content_type: :tv_show))
      non_member = generate(user())

      create_tv_show("43", %{library_ids: [library.id]}, actor: non_member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "get_tv_show_details/*" do
    test "returns TV show details with season summaries" do
      actor = generate(user(locale: :en_US))

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        if String.ends_with?(conn.request_path, "/tv/42") do
          Req.Test.json(conn, tv_details_fixture())
        else
          conn
          |> Plug.Conn.put_status(500)
          |> Req.Test.json(%{})
        end
      end)

      assert %ContentView{
               type: :tv_show,
               external_id: "42",
               title: "The Expanse",
               details: %TvDetailsResponse{
                 backdrop_path: "/backdrop.jpg",
                 status: "Ended",
                 season_details: [],
                 seasons: [
                   %TvDetailsResponse.Season{season_number: 0, episode_count: 1},
                   %TvDetailsResponse.Season{season_number: 1, episode_count: 3},
                   %TvDetailsResponse.Season{season_number: 2, episode_count: 2},
                   %TvDetailsResponse.Season{season_number: 3, episode_count: 0}
                 ]
               }
             } = get_tv_show_details!("42", actor: actor)
    end
  end

  describe "get_tv_show_season_details/*" do
    test "returns TV Show Episode metadata for one season" do
      actor = generate(user(locale: :en_US))

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Req.Test.json(conn, tv_season_details_fixture(1))
      end)

      assert %TvDetailsResponse.SeasonDetails{
               season_number: 1,
               name: "Season 1",
               episodes: [
                 %TvDetailsResponse.SeasonDetails.Episode{
                   episode_number: 1,
                   name: "Dulcinea",
                   overview: "The Canterbury answers a distress call.",
                   runtime: 48,
                   still_path: "/dulcinea.jpg"
                 },
                 %TvDetailsResponse.SeasonDetails.Episode{episode_number: 2}
               ]
             } = get_tv_show_season_details!("42", 1, actor: actor)
    end
  end

  describe "search_content/*" do
    test "attaches existing TMDB content to matching search results", %{
      club: club,
      admin: admin,
      member: member
    } do
      library = generate(library(club, content_type: :movie))
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
      library = generate(library(club, content_type: :movie))
      library_id = library.id
      content = generate(movie(actor: admin))

      assert %Content{library_items: [%LibraryItem{library_id: ^library_id} = item]} =
               set_club_libraries!(content, %{library_ids: [library.id]}, actor: member)

      assert item.library.club_id == club.id
    end

    test "rejects selected club libraries that do not allow the content type", %{
      club: club,
      admin: admin,
      member: member
    } do
      library = generate(library(club, name: "Books", content_type: :book))
      content = generate(movie(actor: admin))

      set_club_libraries(content, %{library_ids: [library.id]}, actor: member)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidChanges{message: "Library does not allow this content type"} ->
          true

        _ ->
          false
      end)
    end

    test "does not remove library items from clubs the actor cannot access", %{
      club: club,
      admin: admin,
      member: member
    } do
      member_library = generate(library(club, content_type: :movie))
      other_club = generate(club(actor: admin))
      other_library = generate(library(other_club, content_type: :movie))

      content =
        create_movie!("13", %{library_ids: [member_library.id, other_library.id]}, actor: admin)

      assert %Content{} =
               set_club_libraries!(content, %{library_ids: [member_library.id]}, actor: member)

      other_library_id = other_library.id

      assert %LibraryItem{library_id: ^other_library_id} =
               LibraryItem
               |> Ash.Query.filter(content_id == ^content.id and library_id == ^other_library.id)
               |> Ash.read_one!(authorize?: false)
    end

    test "removes omitted library items added by the actor", %{club: club, member: member} do
      library = generate(library(club, content_type: :movie))
      content = create_movie!("14", %{library_ids: [library.id]}, actor: member)

      assert %Content{} = set_club_libraries!(content, %{library_ids: []}, actor: member)

      refute LibraryItem
             |> Ash.Query.filter(content_id == ^content.id and library_id == ^library.id)
             |> Ash.exists?(authorize?: false)
    end

    test "preserves omitted library items the actor can access but cannot remove", %{
      club: club,
      admin: admin,
      member: member
    } do
      library = generate(library(club, content_type: :movie))
      content = create_movie!("15", %{library_ids: [library.id]}, actor: admin)

      admin_id = admin.id

      assert %LibraryItem{added_by_id: ^admin_id} =
               library.id
               |> get_library_items!(actor: member)
               |> Enum.find(&(&1.content_id == content.id))

      assert %Content{} = set_club_libraries!(content, %{library_ids: []}, actor: member)

      library_id = library.id

      assert %LibraryItem{library_id: ^library_id, added_by_id: ^admin_id} =
               library.id
               |> get_library_items!(actor: member)
               |> Enum.find(&(&1.content_id == content.id))
    end

    test "preserves omitted library items added by a former member", %{
      club: club,
      member: member,
      membership: membership
    } do
      library = generate(library(club, content_type: :movie))
      content = create_movie!("16", %{library_ids: [library.id]}, actor: member)

      leave_club!(membership, actor: member)

      assert %Content{} = set_club_libraries!(content, %{library_ids: []}, actor: member)

      member_id = member.id
      library_id = library.id

      assert %LibraryItem{library_id: ^library_id, added_by_id: ^member_id} =
               LibraryItem
               |> Ash.Query.filter(content_id == ^content.id and library_id == ^library.id)
               |> Ash.read_one!(authorize?: false)
    end

    test "allows a rejoined member to remove library items they added before leaving", %{
      club: club,
      member: member,
      membership: membership
    } do
      library = generate(library(club, content_type: :movie))
      content = create_movie!("17", %{library_ids: [library.id]}, actor: member)

      leave_club!(membership, actor: member)
      generate(membership(club, member, role: :member))

      assert %Content{} = set_club_libraries!(content, %{library_ids: []}, actor: member)

      refute LibraryItem
             |> Ash.Query.filter(content_id == ^content.id and library_id == ^library.id)
             |> Ash.exists?(authorize?: false)
    end

    test "only club admins can remove orphaned library items", %{
      club: club,
      admin: admin,
      member: member
    } do
      library = generate(library(club, content_type: :movie))
      content = create_movie!("18", %{library_ids: [library.id]}, actor: member)

      LibraryItem
      |> Ash.Query.filter(content_id == ^content.id and library_id == ^library.id)
      |> Ash.read_one!(authorize?: false)
      |> Ash.Seed.update!(%{added_by_id: nil})

      assert %Content{} = set_club_libraries!(content, %{library_ids: []}, actor: member)

      library_id = library.id

      assert %LibraryItem{library_id: ^library_id, added_by_id: nil} =
               LibraryItem
               |> Ash.Query.filter(content_id == ^content.id and library_id == ^library.id)
               |> Ash.read_one!(authorize?: false)

      assert %Content{} = set_club_libraries!(content, %{library_ids: []}, actor: admin)

      refute LibraryItem
             |> Ash.Query.filter(content_id == ^content.id and library_id == ^library.id)
             |> Ash.exists?(authorize?: false)
    end

    test "requires membership in selected libraries", %{club: club, admin: admin} do
      library = generate(library(club, content_type: :movie))
      content = generate(movie(actor: admin))
      non_member = generate(user())

      set_club_libraries(content, %{library_ids: [library.id]}, actor: non_member)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  defp tv_details_fixture do
    %{
      "id" => 42,
      "name" => "The Expanse",
      "original_name" => "The Expanse",
      "original_language" => "en",
      "origin_country" => ["US"],
      "first_air_date" => "2015-12-14",
      "backdrop_path" => "/backdrop.jpg",
      "genres" => [%{"id" => 18, "name" => "Drama"}],
      "homepage" => "https://www.syfy.com/the-expanse",
      "overview" => "A mystery unfolds across the solar system.",
      "poster_path" => "/poster.jpg",
      "production_countries" => [%{"iso_3166_1" => "US", "name" => "United States"}],
      "spoken_languages" => [
        %{"iso_639_1" => "en", "english_name" => "English", "name" => "English"}
      ],
      "status" => "Ended",
      "tagline" => "The future is closer than you think.",
      "vote_average" => 8.4,
      "vote_count" => 2_900,
      "external_ids" => %{"imdb_id" => "tt3230854", "tvdb_id" => 280_619},
      "images" => %{
        "posters" => [
          %{"iso_639_1" => "fr", "file_path" => "/poster-fr.jpg"}
        ]
      },
      "seasons" => [
        %{"season_number" => 0, "episode_count" => 1},
        %{"season_number" => 1, "episode_count" => 3},
        %{"season_number" => 2, "episode_count" => 2},
        %{"season_number" => 3, "episode_count" => 0}
      ],
      "translations" => %{
        "translations" => [
          %{
            "iso_639_1" => "fr",
            "iso_3166_1" => "FR",
            "data" => %{
              "name" => "The Expanse FR",
              "overview" => "Un mystère se déroule dans le système solaire."
            }
          }
        ]
      }
    }
  end

  defp tv_season_details_fixture(1) do
    %{
      "id" => 10_001,
      "name" => "Season 1",
      "season_number" => 1,
      "air_date" => "2015-12-14",
      "overview" => "The Canterbury crew uncovers a conspiracy.",
      "poster_path" => "/season-1.jpg",
      "vote_average" => 7.9,
      "episodes" => [
        %{
          "id" => 100_101,
          "episode_number" => 1,
          "episode_type" => "standard",
          "name" => "Dulcinea",
          "overview" => "The Canterbury answers a distress call.",
          "runtime" => 48,
          "season_number" => 1,
          "show_id" => 42,
          "still_path" => "/dulcinea.jpg",
          "vote_average" => 7.7,
          "vote_count" => 154,
          "air_date" => "2015-12-14"
        },
        %{
          "id" => 100_102,
          "episode_number" => 2,
          "episode_type" => "standard",
          "name" => "The Big Empty",
          "overview" => "Holden and crew are trapped in a damaged shuttle.",
          "runtime" => 46,
          "season_number" => 1,
          "show_id" => 42,
          "still_path" => "/big-empty.jpg",
          "vote_average" => 7.6,
          "vote_count" => 85,
          "air_date" => "2015-12-15"
        }
      ]
    }
  end

  defp tv_season_details_fixture(2) do
    %{
      "id" => 10_002,
      "name" => "Season 2",
      "season_number" => 2,
      "air_date" => "2017-02-01",
      "overview" => "Interplanetary tensions reach an all-time high.",
      "poster_path" => "/season-2.jpg",
      "vote_average" => 8.1,
      "episodes" => [
        %{
          "id" => 100_201,
          "episode_number" => 1,
          "episode_type" => "standard",
          "name" => "Safe",
          "overview" => "The Rocinante crew learns more about the protomolecule.",
          "runtime" => 48,
          "season_number" => 2,
          "show_id" => 42,
          "still_path" => "/safe.jpg",
          "vote_average" => 7.7,
          "vote_count" => 63,
          "air_date" => "2017-02-01"
        }
      ]
    }
  end
end
