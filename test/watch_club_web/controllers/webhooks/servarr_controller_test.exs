defmodule WatchClubWeb.Webhooks.ServarrControllerTest do
  use WatchClubWeb.ConnCase, async: false
  use Oban.Testing, repo: WatchClub.Repo

  import WatchClub.Generator

  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.MediaCatalog
  alias WatchClub.MediaCatalog.Media
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor
  alias WatchClub.MediaSources.{Servarr, Source}
  alias WatchClub.SystemActor

  @token "secret"

  describe "Download" do
    test "authenticated event enqueues a webhook ingest and acks 200", %{conn: conn} do
      source = seed_radarr_source()

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", radarr_download())

      assert json_response(conn, 200) == %{"ok" => true}

      assert_enqueued(
        worker: CandidateIngestor,
        args: %{path: "/data/movies/Star Wars (1977)/movie.mkv"}
      )
    end

    test "a file outside the source root folder enqueues nothing", %{conn: conn} do
      source = seed_radarr_source()
      params = put_in(radarr_download(), ["movie", "folderPath"], "/other/Star Wars (1977)")

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", params)

      assert json_response(conn, 200) == %{"ok" => true}
      refute_enqueued(worker: CandidateIngestor)
    end

    test "a wrong token is rejected with 401 and enqueues nothing", %{conn: conn} do
      source = seed_radarr_source()

      conn =
        conn
        |> put_req_header("x-watchclub-token", "wrong")
        |> post(~p"/webhooks/radarr/#{source.id}", radarr_download())

      assert json_response(conn, 401) == %{"ok" => false}
      refute_enqueued(worker: CandidateIngestor)
    end

    test "a missing token is rejected with 401", %{conn: conn} do
      source = seed_radarr_source()

      conn = post(conn, ~p"/webhooks/radarr/#{source.id}", radarr_download())

      assert json_response(conn, 401) == %{"ok" => false}
    end
  end

  describe "MovieFileDelete" do
    test "removes the Media when the file is gone from disk", %{conn: conn} do
      source = seed_radarr_source()
      path = Path.expand("/data/movies/EO (2022)/eo.mkv")
      seed_media(source, path)

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", movie_file_delete())

      assert json_response(conn, 200) == %{"ok" => true}
      refute media_exists?(source, path)
    end

    test "keeps the Media of another Media Source with the same file", %{conn: conn} do
      source = seed_radarr_source()
      other_source = seed_radarr_source()
      path = Path.expand("/data/movies/EO (2022)/eo.mkv")
      seed_media(other_source, path)

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", movie_file_delete())

      assert json_response(conn, 200) == %{"ok" => true}
      assert media_exists?(other_source, path)
    end

    test "keeps the Media when the file is still present (same-path upgrade)", %{conn: conn} do
      local_root = Path.join(System.tmp_dir!(), "wh-del-#{System.unique_integer([:positive])}")
      file = Path.join([local_root, "EO (2022)", "eo.mkv"])
      File.mkdir_p!(Path.dirname(file))
      File.write!(file, "stub")
      on_exit(fn -> File.rm_rf(local_root) end)

      source = seed_radarr_source(local_root_folder_path: local_root)
      path = Path.expand(file)
      seed_media(source, path)

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", movie_file_delete())

      assert json_response(conn, 200) == %{"ok" => true}
      assert media_exists?(source, path)
    end

    test "is a no-op when no Media exists at the path", %{conn: conn} do
      source = seed_radarr_source()

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", movie_file_delete())

      assert json_response(conn, 200) == %{"ok" => true}
    end
  end

  describe "EpisodeFileDelete" do
    test "removes the Media when the episode file is gone from disk", %{conn: conn} do
      source = seed_sonarr_source()
      path = Path.expand("/data/tv/Friends/Season 01/friends.mkv")
      seed_media(source, path)

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/sonarr/#{source.id}", episode_file_delete())

      assert json_response(conn, 200) == %{"ok" => true}
      refute media_exists?(source, path)
    end
  end

  describe "MovieDelete" do
    @tag :tmp_dir
    test "removes the Movie's Media before Radarr deletes its files", %{
      conn: conn,
      tmp_dir: tmp_dir
    } do
      source = seed_radarr_source()
      movie = generate(movie())
      path = Path.join(tmp_dir, "movie.mkv")
      File.write!(path, "stub")
      generate(video_media(movie, media_source_id: source.id, path: path))

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", movie_delete(movie, true))

      assert json_response(conn, 200) == %{"ok" => true}
      refute media_exists?(source, path)
    end

    test "keeps the Movie's Media when Radarr keeps its files", %{conn: conn} do
      source = seed_radarr_source()
      movie = generate(movie())
      media = generate(video_media(movie, media_source_id: source.id))

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", movie_delete(movie, false))

      assert json_response(conn, 200) == %{"ok" => true}
      assert media_exists?(source, media.path)
    end

    test "keeps the Movie's Media of another Media Source", %{conn: conn} do
      source = seed_radarr_source()
      movie = generate(movie())
      other_media = generate(video_media(movie))

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", movie_delete(movie, true))

      assert json_response(conn, 200) == %{"ok" => true}
      assert MediaCatalog.get_media!(other_media.id, actor: SystemActor.actor())
    end
  end

  describe "SeriesDelete" do
    test "removes the TV Show's Media when Sonarr deletes its files", %{conn: conn} do
      source = seed_sonarr_source()
      tv_show = generate(tv_show(num_seasons: 1, episodes_per_season: 1))
      [episode] = tv_show.tv_show.episodes
      media = generate(video_media(episode, media_source_id: source.id))

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/sonarr/#{source.id}", %{
          "eventType" => "SeriesDelete",
          "deletedFiles" => true,
          "series" => %{"id" => 1, "tmdbId" => String.to_integer(tv_show.external_id)}
        })

      assert json_response(conn, 200) == %{"ok" => true}
      refute media_exists?(source, media.path)
    end
  end

  describe "Rename" do
    test "relocates the Media from the previous path to the new path", %{conn: conn} do
      source = seed_radarr_source()
      old = Path.expand("/data/movies/EO (2022)/old.mkv")
      new = Path.expand("/data/movies/EO (2022)/EO (2022).mkv")
      seed_media(source, old)

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", movie_rename())

      assert json_response(conn, 200) == %{"ok" => true}
      refute media_exists?(source, old)
      assert media_exists?(source, new)
    end

    test "is a no-op when no Media exists at the previous path", %{conn: conn} do
      source = seed_radarr_source()

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", movie_rename())

      assert json_response(conn, 200) == %{"ok" => true}
      refute media_exists?(source, Path.expand("/data/movies/EO (2022)/EO (2022).mkv"))
    end

    test "relocates a Sonarr episode file", %{conn: conn} do
      source = seed_sonarr_source()
      old = Path.expand("/data/tv/Friends/Season 01/old.mkv")
      new = Path.expand("/data/tv/Friends/Season 01/friends-s01e01.mkv")
      seed_media(source, old)

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/sonarr/#{source.id}", episode_rename())

      assert json_response(conn, 200) == %{"ok" => true}
      refute media_exists?(source, old)
      assert media_exists?(source, new)
    end
  end

  describe "other events" do
    test "Test acks 200 without auth and enqueues nothing", %{conn: conn} do
      source = seed_radarr_source()

      conn = post(conn, ~p"/webhooks/radarr/#{source.id}", %{"eventType" => "Test"})

      assert json_response(conn, 200) == %{"ok" => true}
      refute_enqueued(worker: CandidateIngestor)
    end

    test "an ignored event (Grab) acks 200 and enqueues nothing", %{conn: conn} do
      source = seed_radarr_source()

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", %{"eventType" => "Grab", "movie" => %{}})

      assert json_response(conn, 200) == %{"ok" => true}
      refute_enqueued(worker: CandidateIngestor)
    end
  end

  describe "Sportarr Rename" do
    setup do
      previous = Application.get_env(:watch_club, :servarr_req_options)
      Application.put_env(:watch_club, :servarr_req_options, plug: {Req.Test, Client})
      on_exit(fn -> Application.put_env(:watch_club, :servarr_req_options, previous) end)
    end

    test "imports the event's files again and drops its Media whose files are gone", %{
      conn: conn
    } do
      source = seed_sportarr_source()
      event = generate(sports_event(external_id: "ev-028133"))

      Ash.Seed.seed!(Media, %{
        media_source_id: source.id,
        path: "/data/sports/UFC/old.mkv",
        type: :sports_event,
        content_id: event.id
      })

      Req.Test.stub(Client, fn conn ->
        assert conn.request_path == "/api/events/60"

        Req.Test.json(conn, %{
          "id" => 60,
          "externalId" => "ev-028133",
          "files" => [%{"filePath" => "/sports/UFC/UFC 311.mkv", "exists" => true}]
        })
      end)

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/sportarr/#{source.id}", %{
          "eventType" => "Rename",
          "series" => %{"id" => 60, "externalId" => "ev-028133"},
          "renamedCount" => 1
        })

      assert json_response(conn, 200) == %{"ok" => true}
      assert_enqueued(worker: CandidateIngestor, args: %{path: "/data/sports/UFC/UFC 311.mkv"})
      refute media_exists?(source, "/data/sports/UFC/old.mkv")
    end
  end

  defp seed_sportarr_source do
    source =
      Ash.Seed.seed!(Source, %{
        name: "Sportarr",
        source_type: :sportarr,
        media_type: :sports_event
      })

    Ash.Seed.seed!(Servarr, %{
      id: source.id,
      flavor: :sportarr,
      base_url: "http://sportarr.test",
      api_key: "key",
      quality_profile_id: 1,
      quality_profile_name: "WEB-1080p",
      root_folder_path: "/sports",
      local_root_folder_path: "/data/sports",
      webhook_callback_base_url: "http://wc.test",
      webhook_secret: @token,
      notification_id: 1
    })

    source
  end

  defp seed_radarr_source(opts \\ []) do
    source = Ash.Seed.seed!(Source, %{name: "Radarr", source_type: :radarr, media_type: :movie})

    Ash.Seed.seed!(Servarr, %{
      id: source.id,
      flavor: :radarr,
      base_url: "http://radarr.test",
      api_key: "key",
      quality_profile_id: 6,
      quality_profile_name: "HD-1080p",
      root_folder_path: "/movies",
      local_root_folder_path: Keyword.get(opts, :local_root_folder_path, "/data/movies"),
      webhook_callback_base_url: "http://wc.test",
      webhook_secret: @token,
      notification_id: 1
    })

    source
  end

  defp seed_sonarr_source(opts \\ []) do
    source =
      Ash.Seed.seed!(Source, %{name: "Sonarr", source_type: :sonarr, media_type: :tv_show_episode})

    Ash.Seed.seed!(Servarr, %{
      id: source.id,
      flavor: :sonarr,
      base_url: "http://sonarr.test",
      api_key: "key",
      quality_profile_id: 6,
      quality_profile_name: "HD-1080p",
      root_folder_path: "/tv",
      local_root_folder_path: Keyword.get(opts, :local_root_folder_path, "/data/tv"),
      webhook_callback_base_url: "http://wc.test",
      webhook_secret: @token,
      notification_id: 1
    })

    source
  end

  defp seed_media(source, path),
    do: Ash.Seed.seed!(Media, %{media_source_id: source.id, path: path, type: :movie})

  defp media_exists?(source, path) do
    match?({:ok, _}, MediaCatalog.get_media_by_path(source.id, path, actor: SystemActor.actor()))
  end

  defp radarr_download do
    %{
      "eventType" => "Download",
      "movie" => %{
        "tmdbId" => 11,
        "imdbId" => "tt0076759",
        "title" => "Star Wars",
        "year" => 1977,
        "folderPath" => "/movies/Star Wars (1977)"
      },
      "movieFile" => %{
        "relativePath" => "movie.mkv",
        "path" => "/movies/Star Wars (1977)/movie.mkv"
      }
    }
  end

  defp movie_file_delete do
    %{
      "eventType" => "MovieFileDelete",
      "deleteReason" => "manual",
      "movie" => %{"folderPath" => "/movies/EO (2022)"},
      "movieFile" => %{"relativePath" => "eo.mkv", "path" => "/movies/EO (2022)/eo.mkv"}
    }
  end

  defp episode_file_delete do
    %{
      "eventType" => "EpisodeFileDelete",
      "deleteReason" => "manual",
      "series" => %{"path" => "/tv/Friends"},
      "episodeFile" => %{
        "relativePath" => "Season 01/friends.mkv",
        "path" => "/tv/Friends/Season 01/friends.mkv"
      }
    }
  end

  defp movie_delete(movie, deleted_files?) do
    %{
      "eventType" => "MovieDelete",
      "deletedFiles" => deleted_files?,
      "movie" => %{"id" => 1, "tmdbId" => String.to_integer(movie.external_id)}
    }
  end

  defp movie_rename do
    %{
      "eventType" => "Rename",
      "movie" => %{"folderPath" => "/movies/EO (2022)"},
      "renamedMovieFiles" => [
        %{"previousPath" => "/movies/EO (2022)/old.mkv", "relativePath" => "EO (2022).mkv"}
      ]
    }
  end

  defp episode_rename do
    %{
      "eventType" => "Rename",
      "series" => %{"path" => "/tv/Friends"},
      "renamedEpisodeFiles" => [
        %{
          "previousPath" => "/tv/Friends/Season 01/old.mkv",
          "relativePath" => "Season 01/friends-s01e01.mkv"
        }
      ]
    }
  end
end
