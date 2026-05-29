defmodule WatchClub.Media.RadarrImportPipelineTest do
  use ExUnit.Case, async: false

  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.MovieIdentity
  alias WatchClub.Media.{MediaImport, MediaSource, RadarrImportPipeline, ServarrMediaSource}

  setup do
    previous = Application.get_env(:watch_club, :servarr_req_options)

    Application.put_env(:watch_club, :servarr_req_options,
      plug: {Req.Test, Client},
      retry: false
    )

    on_exit(fn -> Application.put_env(:watch_club, :servarr_req_options, previous) end)
    :ok
  end

  defp media_import(config_overrides \\ %{}) do
    config =
      struct(
        %ServarrMediaSource{
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

    %MediaImport{media_source: %MediaSource{source_type: :radarr, implementation: config}}
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

  describe "scan/1" do
    test "emits a candidate with Radarr identity and a locally-mapped path" do
      stub_movies([movie(%{})])

      assert {:ok, [candidate]} = RadarrImportPipeline.scan(media_import())

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

      assert {:ok, [candidate]} =
               RadarrImportPipeline.scan(media_import(%{local_root_folder_path: nil}))

      assert candidate.path == "/movies/Star Wars (1977)/movie.mkv"
    end

    test "skips movies without a downloaded file" do
      stub_movies([movie(%{"hasFile" => false, "movieFile" => nil})])

      assert {:ok, []} = RadarrImportPipeline.scan(media_import())
    end

    test "skips movies from a different quality profile" do
      stub_movies([movie(%{"qualityProfileId" => 8})])

      assert {:ok, []} = RadarrImportPipeline.scan(media_import())
    end

    test "skips movies from a different root folder" do
      stub_movies([movie(%{"rootFolderPath" => "/movies-4k"})])

      assert {:ok, []} = RadarrImportPipeline.scan(media_import())
    end

    test "tolerates a trailing slash on the configured root folder" do
      stub_movies([movie(%{})])

      assert {:ok, [_candidate]} =
               RadarrImportPipeline.scan(media_import(%{root_folder_path: "/movies/"}))
    end

    test "returns an error when the Radarr API fails" do
      Req.Test.stub(Client, fn conn -> Plug.Conn.send_resp(conn, 401, "nope") end)

      assert {:error, _reason} = RadarrImportPipeline.scan(media_import())
    end
  end
end
