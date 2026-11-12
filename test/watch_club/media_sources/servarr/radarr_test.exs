defmodule WatchClub.MediaSources.Servarr.RadarrTest do
  use ExUnit.Case, async: false

  alias WatchClub.Contents.Content
  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.MovieIdentity
  alias WatchClub.MediaSources.Servarr
  alias WatchClub.MediaSources.Servarr.Radarr

  setup do
    previous = Application.get_env(:watch_club, :servarr_req_options)

    Application.put_env(:watch_club, :servarr_req_options, plug: {Req.Test, Client})

    on_exit(fn -> Application.put_env(:watch_club, :servarr_req_options, previous) end)
    :ok
  end

  defp servarr(config_overrides \\ %{}) do
    struct(
      %Servarr{
        flavor: :radarr,
        base_url: "http://radarr.test",
        api_key: "key",
        quality_profile_id: 6,
        quality_profile_name: "HD-1080p",
        root_folder_path: "/movies",
        local_root_folder_path: "/data/movies"
      },
      config_overrides
    )
  end

  defp stub_movies(movies) do
    Req.Test.stub(Client, fn conn ->
      assert conn.request_path == "/api/v3/movie"
      Req.Test.json(conn, movies)
    end)
  end

  defp movie(attrs) do
    Map.merge(
      %{
        "tmdbId" => 11,
        "imdbId" => "tt0076759",
        "title" => "Star Wars",
        "year" => 1977,
        "hasFile" => true,
        "qualityProfileId" => 6,
        "rootFolderPath" => "/movies",
        "movieFile" => %{"path" => "/movies/Star Wars (1977)/movie.mkv"}
      },
      attrs
    )
  end

  describe "scan!/1" do
    test "emits a candidate with Radarr identity and a locally-mapped path" do
      stub_movies([movie(%{})])

      assert [candidate] = Radarr.scan!(servarr())

      assert %Candidate{
               path: "/data/movies/Star Wars (1977)/movie.mkv",
               identity: %MovieIdentity{
                 tmdb_id: 11,
                 imdb_id: "tt0076759",
                 title: "Star Wars",
                 year: 1977
               }
             } = candidate
    end

    test "uses the Radarr path verbatim when there is no local mapping" do
      stub_movies([movie(%{})])

      assert [candidate] = Radarr.scan!(servarr(%{local_root_folder_path: nil}))

      assert candidate.path == "/movies/Star Wars (1977)/movie.mkv"
    end

    test "skips movies without a downloaded file" do
      stub_movies([movie(%{"hasFile" => false, "movieFile" => nil})])

      assert [] = Radarr.scan!(servarr())
    end

    test "skips movies from a different quality profile" do
      stub_movies([movie(%{"qualityProfileId" => 8})])

      assert [] = Radarr.scan!(servarr())
    end

    test "skips movies from a different root folder" do
      stub_movies([movie(%{"rootFolderPath" => "/movies-4k"})])

      assert [] = Radarr.scan!(servarr())
    end

    test "tolerates a trailing slash on the configured root folder" do
      stub_movies([movie(%{})])

      assert [_candidate] = Radarr.scan!(servarr(%{root_folder_path: "/movies/"}))
    end

    test "raises when the Radarr API fails" do
      Req.Test.stub(Client, fn conn -> Plug.Conn.send_resp(conn, 401, "nope") end)

      assert_raise MatchError, fn -> Radarr.scan!(servarr()) end
    end
  end

  describe "submit_request!/2" do
    setup do
      test_pid = self()

      Req.Test.stub(Client, fn
        %{method: "GET"} = conn ->
          Req.Test.json(conn, [])

        %{method: "POST"} = conn ->
          send(test_pid, {:added, conn.body_params})
          Req.Test.json(conn, movie(%{"id" => 42}))
      end)

      :ok
    end

    test "adds an old movie to download as soon as it's found" do
      content = %Content{
        external_id: "11",
        original_title: "Star Wars",
        release_date: ~D[1977-05-25]
      }

      assert {:ok, 42} = Radarr.submit_request!(servarr(), content)
      assert_received {:added, %{"tmdbId" => 11, "minimumAvailability" => "announced"}}
    end

    test "adds a new movie to download once it's released" do
      content = %Content{
        external_id: "11",
        original_title: "Star Wars",
        release_date: Date.utc_today()
      }

      assert {:ok, 42} = Radarr.submit_request!(servarr(), content)
      assert_received {:added, %{"minimumAvailability" => "released"}}
    end
  end
end
