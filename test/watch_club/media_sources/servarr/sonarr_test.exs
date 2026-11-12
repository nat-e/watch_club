defmodule WatchClub.MediaSources.Servarr.SonarrTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.EpisodeIdentity
  alias WatchClub.MediaSources.Import.Candidate.EpisodeIdentity.Episode
  alias WatchClub.MediaSources.Servarr
  alias WatchClub.MediaSources.Servarr.Sonarr

  setup do
    previous = Application.get_env(:watch_club, :servarr_req_options)

    Application.put_env(:watch_club, :servarr_req_options, plug: {Req.Test, Client})

    on_exit(fn -> Application.put_env(:watch_club, :servarr_req_options, previous) end)
    :ok
  end

  defp servarr(config_overrides \\ %{}) do
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
        "title" => "Pilot",
        "airDate" => "2008-01-20",
        "tvdbId" => 349_232,
        "hasFile" => true,
        "episodeFile" => %{"path" => "/tv/Breaking Bad/S01E01.mkv"}
      },
      attrs
    )
  end

  describe "scan!/1" do
    test "emits one candidate per episode file with series identity and locally-mapped path" do
      stub([series(%{})], %{"1" => [episode(%{})]})

      assert [candidate] = Sonarr.scan!(servarr())

      assert %Candidate{
               path: "/data/tv/Breaking Bad/S01E01.mkv",
               identity: %EpisodeIdentity{
                 tvdb_id: 81_189,
                 tmdb_id: 1396,
                 imdb_id: "tt0903747",
                 title: "Breaking Bad",
                 episodes: [
                   %Episode{
                     season_number: 1,
                     episode_number: 1,
                     title: "Pilot",
                     air_date: ~D[2008-01-20],
                     tvdb_id: 349_232
                   }
                 ]
               }
             } = candidate
    end

    test "emits one candidate holding every episode of a file, in order" do
      file = %{"path" => "/tv/Breaking Bad/S01E01-E02.mkv"}

      stub([series(%{})], %{
        "1" => [
          episode(%{"id" => 2, "episodeNumber" => 2, "episodeFile" => file}),
          episode(%{"id" => 1, "episodeFile" => file})
        ]
      })

      assert [%Candidate{identity: %EpisodeIdentity{episodes: episodes}}] =
               Sonarr.scan!(servarr())

      assert [1, 2] = Enum.map(episodes, & &1.episode_number)
    end

    test "uses the Sonarr path verbatim when there is no local mapping" do
      stub([series(%{})], %{"1" => [episode(%{})]})

      assert [candidate] = Sonarr.scan!(servarr(%{local_root_folder_path: nil}))

      assert candidate.path == "/tv/Breaking Bad/S01E01.mkv"
    end

    test "skips episodes without a downloaded file" do
      stub([series(%{})], %{"1" => [episode(%{"hasFile" => false, "episodeFile" => nil})]})

      assert [] = Sonarr.scan!(servarr())
    end

    test "skips series from a different quality profile" do
      stub([series(%{"qualityProfileId" => 8})], %{"1" => [episode(%{})]})

      assert [] = Sonarr.scan!(servarr())
    end

    test "skips series from a different root folder" do
      stub([series(%{"rootFolderPath" => "/tv-4k"})], %{"1" => [episode(%{})]})

      assert [] = Sonarr.scan!(servarr())
    end

    test "tolerates a trailing slash on the configured root folder" do
      stub([series(%{})], %{"1" => [episode(%{})]})

      assert [_candidate] = Sonarr.scan!(servarr(%{root_folder_path: "/tv/"}))
    end

    test "raises when the series API fails" do
      Req.Test.stub(Client, fn conn -> Plug.Conn.send_resp(conn, 401, "nope") end)

      assert_raise MatchError, fn -> Sonarr.scan!(servarr()) end
    end

    test "logs a failed episode list and continues with the other series" do
      stub([series(%{"id" => 1, "title" => "Broken"}), series(%{"id" => 2})], %{
        "1" => 500,
        "2" => [episode(%{})]
      })

      log =
        capture_log(fn ->
          assert [%Candidate{identity: %EpisodeIdentity{title: "Breaking Bad"}}] =
                   Sonarr.scan!(servarr())
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
                   Sonarr.scan!(servarr())
        end)

      assert log =~ "Error listing episodes for: Broken"
    end
  end

  describe "interpret_webhook!/2" do
    test "a Download ingests its file as one candidate holding its episodes" do
      assert [{:ingest, [candidate]}, {:refresh_request, 1}] =
               Sonarr.interpret_webhook!(servarr(), %{
                 "eventType" => "Download",
                 "series" => %{"id" => 1, "tvdbId" => 79_168, "path" => "/tv/Friends"},
                 "episodes" =>
                   for {number, title} <- [
                         {1, "The One with the Proposal (1)"},
                         {2, "The One with the Proposal (2)"}
                       ] do
                     %{
                       "seasonNumber" => 3,
                       "episodeNumber" => number,
                       "title" => title,
                       "airDate" => "1996-05-16",
                       "tvdbId" => 300_000 + number
                     }
                   end,
                 "episodeFile" => %{"relativePath" => "Season 03/S03E01-E02.mkv"}
               })

      assert %Candidate{
               path: "/data/tv/Friends/Season 03/S03E01-E02.mkv",
               identity: %EpisodeIdentity{
                 tvdb_id: 79_168,
                 episodes: [
                   %Episode{season_number: 3, episode_number: 1, tvdb_id: 300_001},
                   %Episode{
                     season_number: 3,
                     episode_number: 2,
                     title: "The One with the Proposal (2)",
                     air_date: ~D[1996-05-16]
                   }
                 ]
               }
             } = candidate
    end
  end
end
