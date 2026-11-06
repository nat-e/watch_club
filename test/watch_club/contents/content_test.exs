defmodule WatchClub.Contents.ContentTest do
  use WatchClub.DataCase

  import ExUnit.CaptureLog
  import WatchClub.Contents

  alias WatchClub.History
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse
  alias WatchClub.MediaCatalog
  alias WatchClub.SystemActor

  alias WatchClub.Contents.{
    Content,
    ContentIdentity,
    Movie,
    MovieLocalization,
    SearchResult,
    SearchResultsPage,
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
               genres: [:adventure, :action, :science_fiction],
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

    test "raises when TMDB fetch fails" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"status_message" => "Not found"})
      end)

      capture_log(fn ->
        assert_raise Ash.Error.Unknown, fn -> create_movie("404", actor: generate(user())) end
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
            "images" => %{"backdrops" => [], "logos" => [], "posters" => []},
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

    test "system actor can create a movie without selecting libraries" do
      assert %Content{type: :movie, external_id: "11"} =
               create_movie!("11", actor: WatchClub.SystemActor.actor())
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
               # Sci-Fi & Fantasy gives both
               genres: [:drama, :science_fiction, :fantasy],
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

    test "maps per-season air dates onto episodes, concurrently and best-effort" do
      actor = generate(user(locale: :en_US))

      # Route the base details vs. the per-season endpoints the concurrent
      # fan-out hits. Season 1's fixture lists 2 episodes though details say 3,
      # so S1E3 has no date — best-effort leaves it nil rather than failing.
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        case Regex.run(~r{/season/(\d+)$}, conn.request_path) do
          [_, season] -> Req.Test.json(conn, tv_season_details_fixture(String.to_integer(season)))
          nil -> Req.Test.json(conn, tv_details_fixture())
        end
      end)

      content = create_tv_show!("42", actor: actor)

      air_dates =
        TvShowEpisode
        |> Ash.Query.filter(tv_show_id == ^content.id)
        |> Ash.read!(authorize?: false)
        |> Map.new(fn ep -> {{ep.season_number, ep.episode_number}, ep.air_date} end)

      assert air_dates[{1, 1}] == ~D[2015-12-14]
      assert air_dates[{1, 2}] == ~D[2015-12-15]
      assert air_dates[{1, 3}] == nil
      assert air_dates[{2, 1}] == ~D[2017-02-01]
      assert air_dates[{2, 2}] == nil
    end

    test "raises when TMDB fetch fails" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"status_message" => "Not found"})
      end)

      capture_log(fn ->
        assert_raise Ash.Error.Unknown, fn -> create_tv_show("404", actor: generate(user())) end
      end)
    end

    test "system actor can create a TV show without selecting libraries" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Req.Test.json(conn, tv_details_fixture())
      end)

      assert %Content{type: :tv_show, external_id: "42"} =
               create_tv_show!("42", actor: WatchClub.SystemActor.actor())
    end
  end

  describe "refresh_tv_show/*" do
    test "mirrors TMDB: inserts missing episodes, preserves existing ones, destroys vanished ones" do
      actor = generate(user(locale: :en_US))
      system = WatchClub.SystemActor.actor()

      # Initial create with the standard fixture (S1: 3 eps, S2: 2 eps).
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Req.Test.json(conn, tv_details_fixture())
      end)

      content = create_tv_show!("42", actor: actor)

      original_episodes =
        TvShowEpisode
        |> Ash.Query.filter(tv_show_id == ^content.id)
        |> Ash.Query.sort(season_number: :asc, episode_number: :asc)
        |> Ash.read!(authorize?: false)

      assert length(original_episodes) == 5

      # Capture the id of S1E1 so we can verify it survives the refresh.
      s1e1_id =
        Enum.find(original_episodes, &(&1.season_number == 1 and &1.episode_number == 1)).id

      # Refresh returns: S1 grows to 4 eps, S2 shrinks to 1 ep.
      refreshed_fixture =
        tv_details_fixture()
        |> Map.put("seasons", [
          %{"season_number" => 0, "episode_count" => 1},
          %{"season_number" => 1, "episode_count" => 4},
          %{"season_number" => 2, "episode_count" => 1}
        ])

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Req.Test.json(conn, refreshed_fixture)
      end)

      assert %Content{type: :tv_show} = refresh_tv_show!(content, actor: system)

      assert [
               %TvShowEpisode{season_number: 1, episode_number: 1, id: ^s1e1_id},
               %TvShowEpisode{season_number: 1, episode_number: 2},
               %TvShowEpisode{season_number: 1, episode_number: 3},
               %TvShowEpisode{season_number: 1, episode_number: 4},
               %TvShowEpisode{season_number: 2, episode_number: 1}
             ] =
               TvShowEpisode
               |> Ash.Query.filter(tv_show_id == ^content.id)
               |> Ash.Query.sort(season_number: :asc, episode_number: :asc)
               |> Ash.read!(authorize?: false)
    end

    test "stores the genres of a TV Show created without them" do
      tv_show = generate(tv_show(num_seasons: 1, episodes_per_season: 1))
      tmdb_id = String.to_integer(tv_show.external_id)

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Req.Test.json(conn, Map.put(tv_details_fixture(), "id", tmdb_id))
      end)

      assert %Content{genres: [:drama, :science_fiction, :fantasy]} =
               refresh_tv_show!(tv_show, actor: SystemActor.actor())
    end
  end

  describe "search_content/*" do
    test "returns Movies and TV Shows, and whether they're in the Library", %{member: member} do
      movie = generate(movie())
      add_video!(movie.id)

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Req.Test.json(conn, %{
          "page" => 1,
          "total_pages" => 3,
          "total_results" => 3,
          "results" => [
            %{
              "media_type" => "movie",
              "id" => String.to_integer(movie.external_id),
              "title" => "Dune",
              "overview" => "",
              "release_date" => "2021-09-15"
            },
            %{"media_type" => "person", "id" => 1, "name" => "Denis Villeneuve"},
            %{
              "media_type" => "tv",
              "id" => 42,
              "name" => "Dune: Prophecy",
              "overview" => "The Bene Gesserit.",
              "first_air_date" => ""
            }
          ]
        })
      end)

      assert %SearchResultsPage{
               page: 1,
               total_pages: 3,
               results: [
                 %SearchResult{title: "Dune", year: 2021, overview: nil, has_media?: true},
                 %SearchResult{
                   identity: %ContentIdentity{type: :tv_show, external_id: "42"},
                   title: "Dune: Prophecy",
                   year: nil,
                   overview: "The Bene Gesserit.",
                   has_media?: false
                 }
               ]
             } =
               search_content!(%{query: "dune"}, actor: member)
    end

    test "searches the Library's titles with has_media?", %{member: member} do
      dune = generate(movie(original_title: "Dune", release_date: ~D[2021-09-15]))
      add_video!(dune.id)
      # Not in the Library
      generate(movie(original_title: "Dune: Part Two"))

      assert %SearchResultsPage{
               page: 1,
               total_pages: 1,
               results: [%SearchResult{title: "Dune", year: 2021, has_media?: true} = result]
             } = search_content!(%{query: "dune", has_media?: true}, actor: member)

      assert result.identity == ContentIdentity.from_content(dune)
    end
  end

  describe "get_contents_in_library/*" do
    test "returns the Content with Media, most recently added first", %{
      member: member
    } do
      # Not in the Library
      generate(movie())
      first_movie = generate(movie())
      tv_show = generate(tv_show(num_seasons: 2, episodes_per_season: 1))
      last_movie = generate(movie())

      add_video!(first_movie.id)
      # Any episode adds a TV Show to the Library
      add_episode_video!(tv_show, 2)
      add_video!(last_movie.id)
      # A new episode doesn't move the TV Show
      add_episode_video!(tv_show, 1)

      first_page = get_contents_in_library!(page: [limit: 2], actor: member)
      assert Enum.map(first_page.results, & &1.id) == [last_movie.id, tv_show.id]

      assert %{results: [%Content{id: first_movie_id}], more?: false} =
               Ash.page!(first_page, :next)

      assert first_movie_id == first_movie.id
    end

    test "keeps the Content with a title that contains the query", %{member: member} do
      amelie = generate(movie(original_title: "Le Fabuleux Destin d'Amélie Poulain"))
      spirited_away = generate(movie(original_title: "千と千尋の神隠し"))

      money_heist =
        generate(
          tv_show(original_title: "La casa de papel", num_seasons: 1, episodes_per_season: 1)
        )

      rename!(MovieLocalization, spirited_away, "Spirited Away")
      rename!(TvShowLocalization, money_heist, "Money Heist")
      add_video!(amelie.id)
      add_video!(spirited_away.id)
      add_episode_video!(money_heist, 1)
      add_video!(generate(movie()).id)

      # Ignoring case and accents
      assert [%Content{id: amelie_id}] =
               get_contents_in_library!(%{query: "AMELIE"}, actor: member)

      # In localized titles
      assert [%Content{id: spirited_away_id}] =
               get_contents_in_library!(%{query: "spirited"}, actor: member)

      assert [%Content{id: money_heist_id}] =
               get_contents_in_library!(%{query: "heist"}, actor: member)

      assert {amelie_id, spirited_away_id, money_heist_id} ==
               {amelie.id, spirited_away.id, money_heist.id}
    end

    test "keeps the Content that matches every filter", %{member: member} do
      watched = generate(movie(release_date: ~D[1994-05-01], genres: [:drama]))

      french =
        generate(
          movie(release_date: ~D[1999-12-31], original_language: "fr", genres: [:comedy, :drama])
        )

      japanese =
        generate(
          movie(release_date: ~D[2015-01-01], original_language: "ja", genres: [:animation])
        )

      tv_show =
        generate(
          tv_show(
            num_seasons: 1,
            episodes_per_season: 1,
            start_date: ~D[1995-01-01],
            genres: [:comedy]
          )
        )

      for movie <- [watched, french, japanese], do: add_video!(movie.id)
      add_episode_video!(tv_show, 1)
      History.mark_content_watched!(ContentIdentity.from_content(watched), actor: member)

      ids = fn filters ->
        filters |> get_contents_in_library!(actor: member) |> MapSet.new(& &1.id)
      end

      assert ids.(%{type: :tv_show}) == MapSet.new([tv_show.id])
      assert ids.(%{not_watched?: true}) == MapSet.new([french.id, japanese.id, tv_show.id])

      assert ids.(%{genres: [:animation, :comedy]}) ==
               MapSet.new([french.id, japanese.id, tv_show.id])

      assert ids.(%{decades: [1990]}) == MapSet.new([watched.id, french.id, tv_show.id])
      assert ids.(%{original_languages: ["fr", "ja"]}) == MapSet.new([french.id, japanese.id])

      assert ids.(%{type: :movie, not_watched?: true, decades: [1990]}) ==
               MapSet.new([french.id])
    end

    test "sorts the Content, the Content without a release date last", %{member: member} do
      for {title, release_date} <- [
            {"Casablanca", ~D[1942-11-26]},
            {"Amélie", nil},
            {"Brazil", ~D[1985-02-20]}
          ] do
        add_video!(generate(movie(original_title: title, release_date: release_date)).id)
      end

      titles = fn sort ->
        first_page = get_contents_in_library!(%{sort: sort}, page: [limit: 2], actor: member)
        Enum.map(first_page.results ++ Ash.page!(first_page, :next).results, & &1.original_title)
      end

      assert titles.(:newest) == ["Brazil", "Casablanca", "Amélie"]
      assert titles.(:oldest) == ["Casablanca", "Brazil", "Amélie"]
      assert titles.(:title) == ["Amélie", "Brazil", "Casablanca"]
    end
  end

  describe "get_library_filter_options/*" do
    test "returns the Library's genres and original languages, most common first, and decades, newest first",
         %{member: member} do
      # Not in the Library
      generate(movie(release_date: ~D[1960-01-01], original_language: "it", genres: [:western]))

      for {release_date, language, genres} <- [
            {~D[1994-01-01], "fr", [:drama]},
            {~D[2015-01-01], "en", [:comedy, :drama]},
            {~D[2019-01-01], "fr", [:animation, :comedy, :drama]},
            {nil, "ja", []}
          ] do
        add_video!(
          generate(movie(release_date: release_date, original_language: language, genres: genres)).id
        )
      end

      assert get_library_filter_options!(actor: member) == %{
               genres: [:drama, :comedy, :animation],
               decades: [2010, 1990],
               original_languages: ["fr", "en", "ja"]
             }
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

      assert %TvDetailsResponse{
               backdrop_path: "/backdrop.jpg",
               status: "Ended",
               season_details: [],
               seasons: [
                 %TvDetailsResponse.Season{season_number: 0, episode_count: 1},
                 %TvDetailsResponse.Season{season_number: 1, episode_count: 3},
                 %TvDetailsResponse.Season{season_number: 2, episode_count: 2},
                 %TvDetailsResponse.Season{season_number: 3, episode_count: 0}
               ]
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

  # Bridge the per-type vocabulary these tests are written in onto the unified
  # create/refresh_metadata actions: create (upsert) the Content from its TMDB identity.
  defp add_video!(movie_id) do
    MediaCatalog.create_or_update_video!(media_movie_input(movie_id), actor: SystemActor.actor())
  end

  # Gives every localization of the Content the title
  defp rename!(localization, content, title) do
    localization
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&(Map.get(&1, :movie_id, Map.get(&1, :tv_show_id)) == content.id))
    |> Enum.each(&Ash.Seed.update!(&1, %{title: title}))
  end

  defp add_episode_video!(tv_show, season_number) do
    episode =
      Ash.get!(
        TvShowEpisode,
        %{tv_show_id: tv_show.id, season_number: season_number, episode_number: 1},
        authorize?: false
      )

    MediaCatalog.create_or_update_video!(media_episode_input(episode.id),
      actor: SystemActor.actor()
    )
  end

  defp create_movie(external_id, opts),
    do: create_content(ContentIdentity.for_movie(external_id), %{}, opts)

  defp create_tv_show(external_id, opts),
    do: create_content(ContentIdentity.for_tv_show(external_id), %{}, opts)

  defp create_movie!(external_id, opts) do
    {:ok, content} = create_movie(external_id, opts)
    content
  end

  defp create_tv_show!(external_id, opts) do
    {:ok, content} = create_tv_show(external_id, opts)
    content
  end

  defp refresh_tv_show(content, opts), do: refresh_metadata(content, %{}, opts)

  defp refresh_tv_show!(content, opts) do
    {:ok, content} = refresh_tv_show(content, opts)
    content
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
      "genres" => [
        %{"id" => 18, "name" => "Drama"},
        %{"id" => 10_765, "name" => "Sci-Fi & Fantasy"}
      ],
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
