defmodule WatchClub.Contents.ContentTest do
  use WatchClub.DataCase, async: false

  import ExUnit.CaptureLog
  import WatchClub.Contents

  alias WatchClub.History
  alias WatchClub.MediaCatalog
  alias WatchClub.SystemActor

  alias WatchClub.Contents.{
    Content,
    ContentIdentity,
    MetadataUnavailable,
    Movie,
    MovieLocalization,
    SearchResult,
    SearchResultsPage,
    TvShow,
    TvShowEpisode,
    TvShowEpisodeLocalization,
    TvShowLocalization
  }

  require Ash.Query

  setup do
    admin = generate(administrator())
    member = generate(user())

    Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
      case Regex.run(~r{/tv/(\d+)/season/(\d+)$}, conn.request_path) do
        [_, _tmdb_id, season] ->
          Req.Test.json(conn, tv_season_details_fixture(String.to_integer(season)))

        nil ->
          case Regex.run(~r{/tv/(\d+)$}, conn.request_path) do
            [_, tmdb_id] ->
              Req.Test.json(conn, Map.put(tv_details_fixture(), "id", String.to_integer(tmdb_id)))

            nil ->
              tmdb_id = conn.request_path |> Path.basename() |> String.to_integer()
              Req.Test.json(conn, Map.put(tmdb_fixture("movie_details_11"), "id", tmdb_id))
          end
      end
    end)

    {:ok, admin: admin, member: member}
  end

  describe "create_content/*" do
    test "creates a movie" do
      actor = generate(user(locale: :fr_FR))

      assert %Content{
               type: :movie,
               external_id_source: :tmdb,
               external_id: "11",
               original_language: "en",
               origin_country: "US",
               genres: [:adventure, :action, :science_fiction],
               rating: 8.2,
               implementation: %Movie{
                 best_localization: %MovieLocalization{
                   iso_639_1: "fr",
                   iso_3166_1: "FR",
                   title: "La Guerre des étoiles"
                 }
               }
             } = content = create_content!(ContentIdentity.for_movie("11"), actor: actor)

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

    test "returns an error when TMDB fetch fails" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"status_message" => "Not found"})
      end)

      capture_log(fn ->
        assert {:error, %Ash.Error.Unknown{} = error} =
                 create_content(ContentIdentity.for_movie("404"), actor: generate(user()))

        assert Enum.any?(error.errors, fn error ->
                 match?(%WatchClub.Contents.MetadataUnavailable{reason: :not_found}, error)
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
             } = create_content!(ContentIdentity.for_movie("12"), actor: generate(user()))
    end

    test "system actor can create a movie without selecting libraries" do
      assert %Content{type: :movie, external_id: "11"} =
               create_content!(ContentIdentity.for_movie("11"),
                 actor: WatchClub.SystemActor.actor()
               )
    end

    test "leaves out the rating of a movie too few people voted on" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        tmdb_id = conn.request_path |> Path.basename() |> String.to_integer()

        response =
          "movie_details_11"
          |> tmdb_fixture()
          |> Map.merge(%{"id" => tmdb_id, "vote_average" => 10.0, "vote_count" => 24})

        Req.Test.json(conn, response)
      end)

      assert %Content{rating: nil} =
               create_content!(ContentIdentity.for_movie("12"), actor: generate(user()))
    end

    test "rounds the rating to one decimal" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        tmdb_id = conn.request_path |> Path.basename() |> String.to_integer()

        response =
          "movie_details_11"
          |> tmdb_fixture()
          |> Map.merge(%{"id" => tmdb_id, "vote_average" => 7.96, "vote_count" => 25})

        Req.Test.json(conn, response)
      end)

      assert %Content{rating: 8.0} =
               create_content!(ContentIdentity.for_movie("12"), actor: generate(user()))
    end

    test "creates a TV show with all available episodes" do
      actor = generate(user(locale: :fr_FR))

      french_season =
        tv_season_details_fixture(1)
        |> Map.update!("episodes", fn [first | rest] ->
          [
            first
            |> Map.put("name", "Dulcinea FR")
            |> Map.put("overview", "Un appel de détresse.")
            | rest
          ]
        end)

      stub_tv_metadata(tv_details_fixture(), %{{1, "fr-FR"} => french_season})

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
                   title: "The Expanse FR",
                   poster_path: "/poster-fr.jpg"
                 }
               }
             } = content = create_content!(ContentIdentity.for_tv_show("42"), actor: actor)

      assert [
               %TvShowEpisode{
                 season_number: 1,
                 episode_number: 1,
                 runtime: 48,
                 best_localization: %TvShowEpisodeLocalization{
                   title: "Dulcinea FR",
                   overview: "Un appel de détresse."
                 }
               },
               %TvShowEpisode{season_number: 1, episode_number: 2},
               %TvShowEpisode{season_number: 2, episode_number: 1}
             ] =
               TvShowEpisode
               |> Ash.Query.filter(tv_show_id == ^content.id)
               |> Ash.Query.sort(season_number: :asc, episode_number: :asc)
               |> Ash.Query.load(:best_localization)
               |> Ash.read!(actor: actor, authorize?: false)
    end

    test "stores only the episode positions returned by the season endpoint" do
      actor = generate(user(locale: :en_US))

      # Root counts can exceed the positions returned by the season endpoints.
      stub_tv_metadata(tv_details_fixture(), %{2 => tv_season_details_fixture(2, [1, 2])})

      content = create_content!(ContentIdentity.for_tv_show("42"), actor: actor)

      air_dates =
        TvShowEpisode
        |> Ash.Query.filter(tv_show_id == ^content.id)
        |> Ash.read!(authorize?: false)
        |> Map.new(fn ep -> {{ep.season_number, ep.episode_number}, ep.air_date} end)

      assert air_dates[{1, 1}] == ~D[2015-12-14]
      assert air_dates[{1, 2}] == ~D[2015-12-15]
      assert Map.get(air_dates, {1, 3}) == nil
      assert air_dates[{2, 1}] == ~D[2017-02-01]
      assert air_dates[{2, 2}] == ~D[2015-12-16]
    end

    test "returns an error when a TV Show fetch fails" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"status_message" => "Not found"})
      end)

      capture_log(fn ->
        assert {:error, %Ash.Error.Unknown{} = error} =
                 create_content(ContentIdentity.for_tv_show("404"), actor: generate(user()))

        assert Enum.any?(error.errors, fn error ->
                 match?(%WatchClub.Contents.MetadataUnavailable{reason: :not_found}, error)
               end)
      end)
    end

    test "system actor can create a TV show without selecting libraries" do
      stub_tv_metadata()

      assert %Content{type: :tv_show, external_id: "42"} =
               create_content!(ContentIdentity.for_tv_show("42"),
                 actor: WatchClub.SystemActor.actor()
               )
    end
  end

  describe "refresh_metadata/*" do
    test "retains absent episodes and refreshes returned episode positions in place" do
      actor = generate(user(locale: :en_US))
      system = WatchClub.SystemActor.actor()

      # Create only the episode positions present in the season endpoint payload.
      stub_tv_metadata(tv_details_fixture(), %{2 => tv_season_details_fixture(2, [1, 2])})

      content = create_content!(ContentIdentity.for_tv_show("42"), actor: actor)

      original_episodes =
        TvShowEpisode
        |> Ash.Query.filter(tv_show_id == ^content.id)
        |> Ash.Query.sort(season_number: :asc, episode_number: :asc)
        |> Ash.read!(authorize?: false)

      assert length(original_episodes) == 4

      # Capture the id of S1E1 so we can verify it survives the refresh.
      s1e1_id =
        Enum.find(original_episodes, &(&1.season_number == 1 and &1.episode_number == 1)).id

      original_s2e2 =
        Enum.find(original_episodes, &(&1.season_number == 2 and &1.episode_number == 2))

      History.mark_content_watched!(
        ContentIdentity.from_content(content),
        %{season_number: 2, episode_number: 2},
        actor: actor
      )

      add_episode_video!(content, 2, 2)

      original_s2e2_with_relations =
        TvShowEpisode
        |> Ash.Query.filter(id == ^original_s2e2.id)
        |> Ash.Query.load([:videos, :watch_progresses])
        |> Ash.read_one!(authorize?: false)

      original_s2e2_localizations =
        TvShowEpisodeLocalization
        |> Ash.read!(authorize?: false)
        |> Enum.filter(&(&1.tv_show_episode_id == original_s2e2.id))
        |> Map.new(&{{&1.iso_639_1, &1.iso_3166_1}, {&1.id, &1.title, &1.overview}})

      original_localization_ids =
        TvShowEpisodeLocalization
        |> Ash.read!(authorize?: false)
        |> Enum.filter(
          &(&1.tv_show_episode_id in Enum.map(original_episodes, fn episode -> episode.id end))
        )
        |> Map.new(&{{&1.tv_show_episode_id, &1.iso_639_1, &1.iso_3166_1}, &1.id})

      # The season endpoint adds S1E4. Missing S2E2 is retained.
      refreshed_fixture =
        tv_details_fixture()
        |> Map.put("seasons", [
          %{"season_number" => 0, "episode_count" => 1},
          %{"season_number" => 1, "episode_count" => 4},
          %{"season_number" => 2, "episode_count" => 1}
        ])

      refreshed_season =
        tv_season_details_fixture(1, [1, 2, 3, 4])
        |> Map.update!("episodes", fn [first | rest] ->
          [Map.put(first, "name", "Dulcinea, Updated") | rest]
        end)

      stub_tv_metadata(refreshed_fixture, %{1 => refreshed_season})

      assert %Content{type: :tv_show} = refresh_metadata!(content, %{}, actor: system)

      assert [
               %TvShowEpisode{season_number: 1, episode_number: 1, id: ^s1e1_id},
               %TvShowEpisode{season_number: 1, episode_number: 2},
               %TvShowEpisode{season_number: 1, episode_number: 3},
               %TvShowEpisode{season_number: 1, episode_number: 4},
               %TvShowEpisode{season_number: 2, episode_number: 1},
               %TvShowEpisode{season_number: 2, episode_number: 2}
             ] =
               TvShowEpisode
               |> Ash.Query.filter(tv_show_id == ^content.id)
               |> Ash.Query.sort(season_number: :asc, episode_number: :asc)
               |> Ash.read!(authorize?: false)

      refreshed_localizations =
        TvShowEpisodeLocalization
        |> Ash.read!(authorize?: false)
        |> Enum.filter(
          &(&1.tv_show_episode_id in Enum.map(original_episodes, fn episode -> episode.id end))
        )

      assert Map.new(
               refreshed_localizations,
               &{{&1.tv_show_episode_id, &1.iso_639_1, &1.iso_3166_1}, &1.id}
             ) ==
               original_localization_ids

      assert Enum.any?(refreshed_localizations, &(&1.title == "Dulcinea, Updated"))

      refreshed_s2e2 =
        TvShowEpisode
        |> Ash.Query.filter(id == ^original_s2e2.id)
        |> Ash.Query.load([:videos, :watch_progresses])
        |> Ash.read_one!(authorize?: false)

      assert refreshed_s2e2.air_date == original_s2e2.air_date
      assert refreshed_s2e2.runtime == original_s2e2.runtime
      assert refreshed_s2e2.still_path == original_s2e2.still_path

      assert Enum.map(refreshed_s2e2.videos, & &1.id) ==
               Enum.map(original_s2e2_with_relations.videos, & &1.id)

      assert Enum.map(refreshed_s2e2.watch_progresses, & &1.id) ==
               Enum.map(original_s2e2_with_relations.watch_progresses, & &1.id)

      assert TvShowEpisodeLocalization
             |> Ash.read!(authorize?: false)
             |> Enum.filter(&(&1.tv_show_episode_id == original_s2e2.id))
             |> Map.new(&{{&1.iso_639_1, &1.iso_3166_1}, {&1.id, &1.title, &1.overview}}) ==
               original_s2e2_localizations
    end

    test "stores the genres and rating of a TV Show created without them" do
      tv_show = generate(tv_show(num_seasons: 1, episodes_per_season: 1))
      tmdb_id = String.to_integer(tv_show.external_id)

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Req.Test.json(conn, Map.put(tv_details_fixture(), "id", tmdb_id))
      end)

      assert %Content{genres: [:drama, :science_fiction, :fantasy], rating: 8.4} =
               refresh_metadata!(tv_show, %{}, actor: SystemActor.actor())
    end
  end

  describe "get_or_refresh_content/*" do
    setup do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:watch_club, :contents, :metadata_fetch, :stop],
          [:watch_club, :contents, :metadata_fetch, :exception],
          [:watch_club, :contents, :metadata_request],
          [:watch_club, :tmdb, :request, :stop]
        ])

      on_exit(fn -> :telemetry.detach(ref) end)
      {:ok, telemetry_ref: ref}
    end

    test "creates missing content and loads its implementation with the caller's actor", %{
      telemetry_ref: ref
    } do
      actor = generate(user(locale: :fr_FR))

      details =
        tmdb_fixture("movie_details_11")
        |> Map.put("id", 871)
        |> Map.put("original_title", "Freshly imported")

      stub_movie_metadata(details)

      assert %Content{
               type: :movie,
               external_id: "871",
               original_title: "Freshly imported",
               metadata_refreshed_at: %DateTime{},
               implementation: %Movie{
                 best_localization: %MovieLocalization{title: "La Guerre des étoiles"}
               }
             } =
               get_or_refresh_content!(ContentIdentity.for_movie("871"),
                 actor: actor,
                 load: [:implementation]
               )

      assert_received {[:watch_club, :contents, :metadata_fetch, :stop], ^ref,
                       %{duration: duration, callers: 1}, %{type: :movie, result: :created}}

      assert duration > 0

      assert_received {[:watch_club, :contents, :metadata_request], ^ref, %{count: 1},
                       %{served: :fetched}}

      for _ <- 1..2 do
        assert_received {[:watch_club, :tmdb, :request, :stop], ^ref, %{duration: duration},
                         %{endpoint: "/movie/:id", status: "2xx"}}

        assert duration > 0
      end
    end

    test "refreshes stale metadata and updates localizations in place", %{
      member: actor,
      telemetry_ref: ref
    } do
      refreshed_at = DateTime.add(DateTime.utc_now(), -25 * 60 * 60, :second)
      content = generate(movie(metadata_refreshed_at: refreshed_at))

      localization_ids =
        MovieLocalization
        |> Ash.Query.filter(movie_id == ^content.id)
        |> Ash.read!(authorize?: false)
        |> Map.new(&{{&1.iso_639_1, &1.iso_3166_1}, &1.id})

      details =
        tmdb_fixture("movie_details_11")
        |> Map.put("id", String.to_integer(content.external_id))
        |> Map.put("original_title", "Corrected title")
        |> Map.put("credits", %{
          "cast" => [
            %{
              "id" => 42,
              "name" => "Mark Hamill",
              "character" => "Luke Skywalker",
              "profile_path" => "/mark-hamill.jpg",
              "order" => 0
            }
          ],
          "crew" => []
        })
        |> Map.put("videos", %{
          "results" => [
            %{
              "id" => "trailer",
              "key" => "abc123",
              "name" => "Official trailer",
              "site" => "YouTube",
              "type" => "Trailer",
              "official" => true
            }
          ]
        })
        |> Map.update!("translations", fn translations ->
          Map.update!(translations, "translations", fn translations ->
            Enum.map(translations, fn translation ->
              if translation["iso_639_1"] == "fr" do
                update_in(translation, ["data"], &Map.put(&1, "title", "Titre corrigé"))
              else
                translation
              end
            end)
          end)
        end)

      stub_movie_metadata(details)

      assert %Content{original_title: "Corrected title", metadata_refreshed_at: new_refreshed_at} =
               get_or_refresh_content!(ContentIdentity.from_content(content), actor: actor)

      assert DateTime.compare(new_refreshed_at, refreshed_at) == :gt

      assert_received {[:watch_club, :contents, :metadata_fetch, :stop], ^ref,
                       %{duration: duration, callers: 1}, %{type: :movie, result: :refreshed}}

      assert duration > 0

      localizations =
        MovieLocalization
        |> Ash.Query.filter(movie_id == ^content.id)
        |> Ash.read!(authorize?: false)

      assert Map.new(localizations, &{{&1.iso_639_1, &1.iso_3166_1}, &1.id}) == localization_ids
      assert Enum.find(localizations, &(&1.iso_639_1 == "fr")).title == "Titre corrigé"

      assert Enum.all?(localizations, fn localization ->
               localization.cast == [
                 %WatchClub.Contents.CastMember{
                   name: "Mark Hamill",
                   role: "Luke Skywalker",
                   profile_path: "/mark-hamill.jpg"
                 }
               ] and localization.trailer_url == "https://www.youtube.com/watch?v=abc123"
             end)
    end

    test "keeps Movies and TV Shows with the same TMDB ID separate", %{member: actor} do
      movie = get_or_refresh_content!(ContentIdentity.for_movie(42), actor: actor)
      tv_show = get_or_refresh_content!(ContentIdentity.for_tv_show(42), actor: actor)

      assert movie.type == :movie
      assert tv_show.type == :tv_show
      assert movie.id != tv_show.id

      assert get_or_refresh_content!(ContentIdentity.for_movie(42), actor: actor).id == movie.id

      assert get_or_refresh_content!(ContentIdentity.for_tv_show(42), actor: actor).id ==
               tv_show.id
    end

    test "concurrent creators share one fetch and load with each caller's actor", %{
      member: actor,
      telemetry_ref: ref
    } do
      parent = self()
      french_user = generate(user(locale: :fr_FR))

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        send(parent, {:fetched_movie_metadata, URI.decode_query(conn.query_string)["language"]})

        if URI.decode_query(conn.query_string)["language"] == "en-US" do
          send(parent, {:fetch_started, self()})
          receive do: (:finish_fetch -> :ok)
        end

        Req.Test.json(conn, tmdb_fixture("movie_details_11"))
      end)

      callers =
        for user <- [actor, french_user, actor, french_user] do
          Task.async(fn ->
            get_or_refresh_content!(ContentIdentity.for_movie(11),
              actor: user,
              load: [:implementation]
            )
          end)
        end

      assert_receive {:fetch_started, fetch}
      await_metadata_callers(4)
      send(fetch, :finish_fetch)
      contents = Task.await_many(callers)

      assert length(Enum.uniq_by(contents, & &1.id)) == 1

      assert Enum.map(contents, & &1.implementation.best_localization.title) ==
               ["Star Wars", "La Guerre des étoiles", "Star Wars", "La Guerre des étoiles"]

      assert_receive {:fetched_movie_metadata, "en-US"}
      assert_receive {:fetched_movie_metadata, "fr-FR"}
      refute_receive {:fetched_movie_metadata, _}, 0

      assert_received {[:watch_club, :contents, :metadata_fetch, :stop], ^ref,
                       %{duration: duration, callers: 4}, %{type: :movie, result: :created}}

      assert duration > 0
      refute_received {[:watch_club, :contents, :metadata_fetch, :stop], ^ref, _, _}

      for _ <- 1..4 do
        assert_received {[:watch_club, :contents, :metadata_request], ^ref, _,
                         %{served: :fetched}}
      end
    end

    test "concurrent callers share one failed refresh and all receive stored Content", %{
      member: actor,
      telemetry_ref: ref
    } do
      content =
        generate(movie(metadata_refreshed_at: DateTime.add(DateTime.utc_now(), -2, :day)))

      parent = self()

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        send(parent, {:fetch_started, self()})
        receive do: (:finish_fetch -> :ok)
        Plug.Conn.send_resp(conn, 503, "")
      end)

      log =
        capture_log(fn ->
          callers =
            for _ <- 1..4 do
              Task.async(fn ->
                get_or_refresh_content!(ContentIdentity.from_content(content), actor: actor)
              end)
            end

          assert_receive {:fetch_started, fetch}
          await_metadata_callers(4)
          send(fetch, :finish_fetch)

          for stored <- Task.await_many(callers) do
            assert stored.id == content.id
            assert stored.metadata_refreshed_at == content.metadata_refreshed_at
            assert stored.updated_at == content.updated_at
          end

          refute_receive {:fetch_started, _}, 0
        end)

      assert length(Regex.scan(~r/Content metadata is unavailable/, log)) == 1

      assert_received {[:watch_club, :contents, :metadata_fetch, :stop], ^ref, %{callers: 4},
                       %{type: :movie, result: :kept_stored}}

      refute_received {[:watch_club, :contents, :metadata_fetch, :stop], ^ref, _, _}
    end

    test "unexpected fetch crashes exit every waiting caller", %{
      member: actor,
      telemetry_ref: ref
    } do
      parent = self()

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn _conn ->
        send(parent, {:fetch_started, self()})
        receive do: (:finish_fetch -> :ok)
        raise "broken metadata"
      end)

      capture_log(fn ->
        callers =
          for _ <- 1..4 do
            Task.async(fn ->
              catch_exit(get_or_refresh_content(ContentIdentity.for_movie(11), actor: actor))
            end)
          end

        assert_receive {:fetch_started, fetch}
        await_metadata_callers(4)
        send(fetch, :finish_fetch)

        for reason <- Task.await_many(callers) do
          assert {%Ash.Error.Unknown{} = error, stacktrace} = reason
          assert Exception.message(error) =~ "broken metadata"
          assert stacktrace != []
        end

        refute_receive {:fetch_started, _}, 0

        assert_received {[:watch_club, :contents, :metadata_fetch, :exception], ^ref,
                         %{duration: duration, callers: 4},
                         %{type: :movie, kind: :exit, stacktrace: stacktrace}}

        assert duration > 0
        assert stacktrace != []
        refute_received {[:watch_club, :contents, :metadata_fetch, :exception], ^ref, _, _}
        refute_received {[:watch_club, :contents, :metadata_fetch, :stop], ^ref, _, _}
      end)
    end

    test "respects a shorter max_age", %{member: actor} do
      refreshed_at = DateTime.add(DateTime.utc_now(), -16, :minute)
      content = generate(movie(metadata_refreshed_at: refreshed_at))

      assert %Content{id: id, metadata_refreshed_at: new_refreshed_at} =
               get_or_refresh_content!(ContentIdentity.from_content(content), %{max_age: 15 * 60},
                 actor: actor
               )

      assert id == content.id
      assert DateTime.compare(new_refreshed_at, refreshed_at) == :gt
    end

    test "max_age: :infinity never refreshes stored Content", %{member: actor} do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn _conn ->
        flunk("any-age metadata must not make a TMDB request")
      end)

      for refreshed_at <- [DateTime.add(DateTime.utc_now(), -2, :day), nil] do
        content = generate(movie(metadata_refreshed_at: refreshed_at))

        assert %Content{id: id, metadata_refreshed_at: ^refreshed_at, updated_at: updated_at} =
                 get_or_refresh_content!(
                   ContentIdentity.from_content(content),
                   %{max_age: :infinity},
                   actor: actor
                 )

        assert id == content.id
        assert updated_at == content.updated_at
      end
    end

    test "returns fresh content without HTTP requests or writes", %{
      member: actor,
      telemetry_ref: ref
    } do
      refreshed_at = DateTime.add(DateTime.utc_now(), -60, :second)
      content = generate(movie(metadata_refreshed_at: refreshed_at))
      original_updated_at = content.updated_at

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn _conn ->
        flunk("fresh metadata must not make a TMDB request")
      end)

      assert %Content{
               id: id,
               metadata_refreshed_at: ^refreshed_at,
               updated_at: ^original_updated_at
             } =
               get_or_refresh_content!(ContentIdentity.from_content(content), actor: actor)

      assert id == content.id

      assert_received {[:watch_club, :contents, :metadata_request], ^ref, %{count: 1},
                       %{served: :stored}}

      refute_received {[:watch_club, :contents, :metadata_fetch, :stop], ^ref, _, _}
    end

    test "returns stored content unchanged when a refresh fails", %{member: actor} do
      refreshed_at = DateTime.add(DateTime.utc_now(), -25 * 60 * 60, :second)
      content = generate(movie(metadata_refreshed_at: refreshed_at))

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Plug.Conn.send_resp(conn, 503, "")
      end)

      assert %Content{id: id, metadata_refreshed_at: ^refreshed_at} =
               get_or_refresh_content!(ContentIdentity.from_content(content), actor: actor)

      assert id == content.id
    end

    test "keeps stale TV Show data when one season localization fails", %{member: actor} do
      refreshed_at = DateTime.add(DateTime.utc_now(), -25 * 60 * 60, :second)

      content =
        generate(
          tv_show(
            num_seasons: 2,
            episodes_per_season: 1,
            metadata_refreshed_at: refreshed_at
          )
        )

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        case Regex.run(~r{/tv/(\d+)/season/(\d+)$}, conn.request_path) do
          [_, _tmdb_id, "2"] ->
            if URI.decode_query(conn.query_string)["language"] == "fr-FR" do
              Plug.Conn.send_resp(conn, 503, "")
            else
              Req.Test.json(conn, tv_season_details_fixture(2))
            end

          [_, _tmdb_id, _season] ->
            Req.Test.json(conn, tv_season_details_fixture(1))

          nil ->
            [_, tmdb_id] = Regex.run(~r{/tv/(\d+)$}, conn.request_path)
            Req.Test.json(conn, Map.put(tv_details_fixture(), "id", String.to_integer(tmdb_id)))
        end
      end)

      episodes_before =
        TvShowEpisode
        |> Ash.Query.filter(tv_show_id == ^content.id)
        |> Ash.read!(authorize?: false)

      assert %Content{metadata_refreshed_at: ^refreshed_at} =
               get_or_refresh_content!(ContentIdentity.from_content(content), actor: actor)

      assert Ash.get!(Content, content.id, authorize?: false).original_title ==
               content.original_title

      assert TvShowEpisode
             |> Ash.Query.filter(tv_show_id == ^content.id)
             |> Ash.read!(authorize?: false) == episodes_before
    end

    test "returns a metadata error when content is missing upstream", %{
      member: actor,
      telemetry_ref: ref
    } do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"status_message" => "Not found"})
      end)

      get_or_refresh_content(ContentIdentity.for_movie("404"), actor: actor)
      |> assert_has_error(Ash.Error.Unknown, fn error ->
        match?(%MetadataUnavailable{reason: :not_found}, error)
      end)

      assert_received {[:watch_club, :contents, :metadata_fetch, :stop], ^ref, %{callers: 1},
                       %{type: :movie, result: :not_found}}

      assert_received {[:watch_club, :tmdb, :request, :stop], ^ref, %{duration: duration},
                       %{endpoint: "/movie/:id", status: "404"}}

      assert duration > 0
    end

    test "returns an error when Content is not stored and TMDB is unavailable", %{
      member: actor,
      telemetry_ref: ref
    } do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Plug.Conn.send_resp(conn, 503, "")
      end)

      get_or_refresh_content(ContentIdentity.for_movie(11), actor: actor)
      |> assert_has_error(Ash.Error.Unknown, fn error ->
        match?(%MetadataUnavailable{reason: :server_error}, error)
      end)

      assert_received {[:watch_club, :contents, :metadata_fetch, :stop], ^ref, %{callers: 1},
                       %{type: :movie, result: :unavailable}}

      assert_received {[:watch_club, :tmdb, :request, :stop], ^ref, %{duration: duration},
                       %{endpoint: "/movie/:id", status: "5xx"}}

      assert duration > 0
    end

    test "returns a metadata error when TMDB rate limits requests", %{
      member: actor,
      telemetry_ref: ref
    } do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Plug.Conn.send_resp(conn, 429, "")
      end)

      get_or_refresh_content(ContentIdentity.for_movie(11), actor: actor)
      |> assert_has_error(Ash.Error.Unknown, fn error ->
        match?(%MetadataUnavailable{reason: :rate_limited}, error)
      end)

      assert_received {[:watch_club, :tmdb, :request, :stop], ^ref, _,
                       %{endpoint: "/movie/:id", status: "429"}}
    end

    test "returns a metadata error when TMDB rejects the request", %{
      member: actor,
      telemetry_ref: ref
    } do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Plug.Conn.send_resp(conn, 401, "")
      end)

      get_or_refresh_content(ContentIdentity.for_movie(11), actor: actor)
      |> assert_has_error(Ash.Error.Unknown, fn error ->
        match?(%MetadataUnavailable{reason: :client_error}, error)
      end)

      assert_received {[:watch_club, :tmdb, :request, :stop], ^ref, _,
                       %{endpoint: "/movie/:id", status: "4xx"}}
    end

    test "returns a metadata error when the TMDB connection times out", %{
      member: actor,
      telemetry_ref: ref
    } do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      get_or_refresh_content(ContentIdentity.for_movie(11), actor: actor)
      |> assert_has_error(Ash.Error.Unknown, fn error ->
        match?(%MetadataUnavailable{reason: :unknown_error}, error)
      end)

      assert_received {[:watch_club, :tmdb, :request, :stop], ^ref, _,
                       %{endpoint: "/movie/:id", status: "error"}}
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
      watched = generate(movie(release_date: ~D[1994-05-01], genres: [:drama], rating: 7.0))

      french =
        generate(
          movie(
            release_date: ~D[1999-12-31],
            original_language: "fr",
            genres: [:comedy, :drama],
            rating: 6.9
          )
        )

      japanese =
        generate(
          movie(
            release_date: ~D[2015-01-01],
            original_language: "ja",
            genres: [:animation],
            rating: 8.6
          )
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
      assert ids.(%{min_rating: 7}) == MapSet.new([watched.id, japanese.id])

      assert ids.(%{type: :movie, not_watched?: true, decades: [1990]}) ==
               MapSet.new([french.id])
    end

    test "sorts the Content, the Content without a release date or rating last", %{
      member: member
    } do
      for {title, release_date, rating} <- [
            {"Casablanca", ~D[1942-11-26], 8.1},
            {"Amélie", nil, nil},
            {"Brazil", ~D[1985-02-20], 7.8}
          ] do
        add_video!(
          generate(movie(original_title: title, release_date: release_date, rating: rating)).id
        )
      end

      titles = fn sort ->
        first_page = get_contents_in_library!(%{sort: sort}, page: [limit: 2], actor: member)
        Enum.map(first_page.results ++ Ash.page!(first_page, :next).results, & &1.original_title)
      end

      assert titles.(:best_rated) == ["Casablanca", "Brazil", "Amélie"]
      assert titles.(:newest) == ["Brazil", "Casablanca", "Amélie"]
      assert titles.(:oldest) == ["Casablanca", "Brazil", "Amélie"]
      assert titles.(:title) == ["Amélie", "Brazil", "Casablanca"]
    end

    test "keeps the Content other Users recommended to the actor", %{member: member} do
      [friend, stranger] = generate_many(user(), 2)
      [recommended, recommended_by_member, recommended_to_stranger] = generate_many(movie(), 3)
      Enum.each([recommended, recommended_by_member, recommended_to_stranger], &add_video!(&1.id))
      generate(conversation(friend, recommended, [member]))
      generate(conversation(member, recommended_by_member, [friend]))
      generate(conversation(friend, recommended_to_stranger, [stranger]))

      assert [%Content{id: id}] = get_contents_in_library!(%{recommended?: true}, actor: member)
      assert id == recommended.id
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

  # Keep the HTTP request blocked until every caller has joined the same fetch.
  defp await_metadata_callers(count, attempts \\ 100)

  defp await_metadata_callers(_count, 0), do: flunk("callers did not join the metadata fetch")

  defp await_metadata_callers(count, attempts) do
    callers =
      WatchClub.Contents.MetadataFetcher
      |> :sys.get_state()
      |> Map.values()
      |> Enum.flat_map(& &1.callers)

    if length(callers) == count do
      :ok
    else
      Process.sleep(10)
      await_metadata_callers(count, attempts - 1)
    end
  end

  defp stub_movie_metadata(details) do
    Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
      Req.Test.json(conn, details)
    end)
  end

  defp stub_tv_metadata(details \\ tv_details_fixture(), season_details \\ %{}) do
    Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
      case Regex.run(~r{/tv/(\d+)/season/(\d+)$}, conn.request_path) do
        [_, tmdb_id, season] ->
          season = String.to_integer(season)
          language = URI.decode_query(conn.query_string)["language"]

          response =
            Map.get(
              season_details,
              {season, language},
              Map.get(season_details, season, tv_season_details_fixture(season))
            )

          Req.Test.json(conn, Map.put(response, "id", String.to_integer(tmdb_id)))

        nil ->
          [_, tmdb_id] = Regex.run(~r{/tv/(\d+)$}, conn.request_path)

          Req.Test.json(
            conn,
            details |> Map.put("id", String.to_integer(tmdb_id)) |> filter_tmdb_posters(conn)
          )
      end
    end)
  end

  # Like TMDB: the posters in `include_image_language`, else only those in the request's language
  defp filter_tmdb_posters(%{"images" => %{"posters" => posters}} = details, conn) do
    query = URI.decode_query(conn.query_string)

    languages =
      String.split(query["include_image_language"] || String.slice(query["language"], 0, 2), ",")

    put_in(
      details,
      ["images", "posters"],
      Enum.filter(posters, &((&1["iso_639_1"] || "null") in languages))
    )
  end

  defp filter_tmdb_posters(details, _conn), do: details

  defp tv_season_details_fixture(season_number, episode_numbers) do
    fixture = tv_season_details_fixture(season_number)
    existing = Map.new(fixture["episodes"], &{&1["episode_number"], &1})

    episodes =
      Enum.map(episode_numbers, fn episode_number ->
        Map.get(existing, episode_number, %{
          "episode_number" => episode_number,
          "season_number" => season_number,
          "name" => "Episode #{episode_number}",
          "overview" => "Episode #{episode_number} overview",
          "runtime" => 45,
          "air_date" => "2015-12-16",
          "still_path" => "/episode-#{episode_number}.jpg"
        })
      end)

    Map.put(fixture, "episodes", episodes)
  end

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

  defp add_episode_video!(tv_show, season_number, episode_number \\ 1) do
    episode =
      Ash.get!(
        TvShowEpisode,
        %{tv_show_id: tv_show.id, season_number: season_number, episode_number: episode_number},
        authorize?: false
      )

    MediaCatalog.create_or_update_video!(media_episode_input(episode.id),
      actor: SystemActor.actor()
    )
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
