defmodule WatchClubWeb.Webhooks.ServarrControllerTest do
  use WatchClubWeb.ConnCase, async: false
  use Oban.Testing, repo: WatchClub.Repo

  alias WatchClub.MediaSources.{Servarr, Source}
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor

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

  defp seed_radarr_source do
    source = Ash.Seed.seed!(Source, %{name: "Radarr", source_type: :radarr, media_type: :movie})

    Ash.Seed.seed!(Servarr, %{
      id: source.id,
      flavor: :radarr,
      base_url: "http://radarr.test",
      api_key: "key",
      quality_profile_id: 6,
      quality_profile_name: "HD-1080p",
      root_folder_path: "/movies",
      local_root_folder_path: "/data/movies",
      webhook_callback_base_url: "http://wc.test",
      webhook_secret: @token,
      notification_id: 1
    })

    source
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
end
