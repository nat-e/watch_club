defmodule WatchClub.MediaSources.Import.Scanner.SonarrTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.MediaSources.{Import, Servarr, Source}
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.EpisodeIdentity
  alias WatchClub.MediaSources.Import.Scanner.Sonarr

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
        %Servarr{
          flavor: :sonarr,
          base_url: "http://sonarr.test",
          api_key: "key",
          quality_profile_id: 6,
          quality_profile_name: "HD-1080p",
          root_folder_path: "/tv",
          local_root_folder_path: "/data/tv"
        },
        config_overrides
      )

    %Import{media_source: %Source{source_type: :sonarr, implementation: config}}
  end

  # Routes the two-call scan: `/series` then `/episode?seriesId=…`.
  # An integer in place of a series' episodes makes that call fail with this status.
  defp stub(series, episodes_by_series_id) do
    Req.Test.stub(Client, fn conn ->
      case conn.request_path do
        "/api/v3/series" ->
          Req.Test.json(conn, series)

        "/api/v3/episode" ->
          series_id = conn.params["seriesId"] |> to_string()

          case Map.get(episodes_by_series_id, series_id, []) do
            status when is_integer(status) -> Plug.Conn.send_resp(conn, status, "nope")
            episodes -> Req.Test.json(conn, episodes)
          end
      end
    end)
  end

  defp series(attrs) do
    Map.merge(
      %{
        "id" => 1,
        "tvdbId" => 81_189,
        "imdbId" => "tt0903747",
        "tmdbId" => 1396,
        "title" => "Breaking Bad",
        "qualityProfileId" => 6,
        "rootFolderPath" => "/tv",
        "status" => "continuing"
      },
      attrs
    )
  end

  defp episode(attrs) do
    Map.merge(
      %{
        "id" => 1,
        "seriesId" => 1,
        "seasonNumber" => 1,
        "episodeNumber" => 1,
        "hasFile" => true,
        "episodeFile" => %{"path" => "/tv/Breaking Bad/S01E01.mkv"}
      },
      attrs
    )
  end

  describe "scan/1" do
    test "emits one candidate per downloaded episode with series identity and locally-mapped path" do
      stub([series(%{})], %{"1" => [episode(%{})]})

      assert [candidate] = Sonarr.scan(media_import())

      assert %Candidate{
               path: "/data/tv/Breaking Bad/S01E01.mkv",
               identity: %EpisodeIdentity{
                 tvdb_id: 81_189,
                 tmdb_id: 1396,
                 imdb_id: "tt0903747",
                 title: "Breaking Bad",
                 season_number: 1,
                 episode_number: 1
               }
             } = candidate
    end

    test "uses the Sonarr path verbatim when there is no local mapping" do
      stub([series(%{})], %{"1" => [episode(%{})]})

      assert [candidate] = Sonarr.scan(media_import(%{local_root_folder_path: nil}))

      assert candidate.path == "/tv/Breaking Bad/S01E01.mkv"
    end

    test "skips episodes without a downloaded file" do
      stub([series(%{})], %{"1" => [episode(%{"hasFile" => false, "episodeFile" => nil})]})

      assert [] = Sonarr.scan(media_import())
    end

    test "skips series from a different quality profile" do
      stub([series(%{"qualityProfileId" => 8})], %{"1" => [episode(%{})]})

      assert [] = Sonarr.scan(media_import())
    end

    test "skips series from a different root folder" do
      stub([series(%{"rootFolderPath" => "/tv-4k"})], %{"1" => [episode(%{})]})

      assert [] = Sonarr.scan(media_import())
    end

    test "tolerates a trailing slash on the configured root folder" do
      stub([series(%{})], %{"1" => [episode(%{})]})

      assert [_candidate] = Sonarr.scan(media_import(%{root_folder_path: "/tv/"}))
    end

    test "raises when the series API fails" do
      Req.Test.stub(Client, fn conn -> Plug.Conn.send_resp(conn, 401, "nope") end)

      assert_raise MatchError, fn -> Sonarr.scan(media_import()) end
    end

    test "logs a failed episode list and continues with the other series" do
      stub([series(%{"id" => 1, "title" => "Broken"}), series(%{"id" => 2})], %{
        "1" => 500,
        "2" => [episode(%{})]
      })

      log =
        capture_log(fn ->
          assert [%Candidate{identity: %EpisodeIdentity{title: "Breaking Bad"}}] =
                   Sonarr.scan(media_import())
        end)

      assert log =~ "Error listing episodes for: Broken"
    end

    test "continues with the other series when the episode list is forbidden" do
      stub([series(%{"id" => 1, "title" => "Broken"}), series(%{"id" => 2})], %{
        "1" => 403,
        "2" => [episode(%{})]
      })

      log =
        capture_log(fn ->
          assert [%Candidate{identity: %EpisodeIdentity{title: "Breaking Bad"}}] =
                   Sonarr.scan(media_import())
        end)

      assert log =~ "Error listing episodes for: Broken"
    end
  end
end
