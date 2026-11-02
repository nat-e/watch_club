defmodule WatchClubWeb.Webhooks.ServarrControllerTest do
  use WatchClubWeb.ConnCase, async: false
  use Oban.Testing, repo: WatchClub.Repo

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
      seed_media(path)

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", movie_file_delete())

      assert json_response(conn, 200) == %{"ok" => true}
      refute media_exists?(path)
    end

    test "keeps the Media when the file is still present (same-path upgrade)", %{conn: conn} do
      local_root = Path.join(System.tmp_dir!(), "wh-del-#{System.unique_integer([:positive])}")
      file = Path.join([local_root, "EO (2022)", "eo.mkv"])
      File.mkdir_p!(Path.dirname(file))
      File.write!(file, "stub")
      on_exit(fn -> File.rm_rf(local_root) end)

      source = seed_radarr_source(local_root_folder_path: local_root)
      path = Path.expand(file)
      seed_media(path)

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", movie_file_delete())

      assert json_response(conn, 200) == %{"ok" => true}
      assert media_exists?(path)
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
      seed_media(path)

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/sonarr/#{source.id}", episode_file_delete())

      assert json_response(conn, 200) == %{"ok" => true}
      refute media_exists?(path)
    end
  end

  describe "Rename" do
    test "relocates the Media from the previous path to the new path", %{conn: conn} do
      source = seed_radarr_source()
      old = Path.expand("/data/movies/EO (2022)/old.mkv")
      new = Path.expand("/data/movies/EO (2022)/EO (2022).mkv")
      seed_media(old)

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", movie_rename())

      assert json_response(conn, 200) == %{"ok" => true}
      refute media_exists?(old)
      assert media_exists?(new)
    end

    test "is a no-op when no Media exists at the previous path", %{conn: conn} do
      source = seed_radarr_source()

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/radarr/#{source.id}", movie_rename())

      assert json_response(conn, 200) == %{"ok" => true}
      refute media_exists?(Path.expand("/data/movies/EO (2022)/EO (2022).mkv"))
    end

    test "relocates a Sonarr episode file", %{conn: conn} do
      source = seed_sonarr_source()
      old = Path.expand("/data/tv/Friends/Season 01/old.mkv")
      new = Path.expand("/data/tv/Friends/Season 01/friends-s01e01.mkv")
      seed_media(old)

      conn =
        conn
        |> put_req_header("x-watchclub-token", @token)
        |> post(~p"/webhooks/sonarr/#{source.id}", episode_rename())

      assert json_response(conn, 200) == %{"ok" => true}
      refute media_exists?(old)
      assert media_exists?(new)
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

  defp seed_media(path), do: Ash.Seed.seed!(Media, %{path: path, type: :movie})

  defp media_exists?(path) do
    match?({:ok, _}, MediaCatalog.get_media_by_path(path, actor: SystemActor.actor()))
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
