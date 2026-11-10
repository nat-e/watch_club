defmodule WatchClub.MediaSources.Servarr.SportarrTest do
  use WatchClub.DataCase, async: false

  alias WatchClub.Contents.ContentIdentity
  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.SportsEventIdentity
  alias WatchClub.MediaSources.Servarr
  alias WatchClub.MediaSources.Servarr.Sportarr

  setup do
    previous = Application.get_env(:watch_club, :servarr_req_options)
    Application.put_env(:watch_club, :servarr_req_options, plug: {Req.Test, Client})
    on_exit(fn -> Application.put_env(:watch_club, :servarr_req_options, previous) end)
    :ok
  end

  @servarr %Servarr{
    flavor: :sportarr,
    base_url: "http://sportarr.test",
    api_key: "key",
    quality_profile_id: 1,
    root_folder_path: "/sports",
    local_root_folder_path: "/data/sports"
  }

  # Routes Sportarr's API by method and path; unknown calls fail the test.
  defp stub_sportarr(routes) do
    Req.Test.stub(Client, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      route = {conn.method, conn.request_path}

      case Map.fetch(routes, route) do
        {:ok, response} when is_function(response, 1) -> Req.Test.json(conn, response.(conn))
        {:ok, response} -> Req.Test.json(conn, response)
        :error -> flunk("unexpected Sportarr call: #{inspect(route)}")
      end
    end)
  end

  defp event(attrs) do
    Map.merge(
      %{
        "id" => 60,
        "externalId" => "ev-028133",
        "monitored" => true,
        "hasFile" => false,
        "eventDate" => "2025-01-19T01:00:00Z",
        "files" => []
      },
      attrs
    )
  end

  defp file(path), do: %{"filePath" => path, "exists" => true}

  describe "scan/1" do
    test "emits one Candidate per file under the root folder, with the event's Sportarr ID" do
      stub_sportarr(%{
        {"GET", "/api/leagues"} => [%{"id" => 1, "externalId" => "lg-000079"}],
        {"GET", "/api/leagues/1/events"} => %{
          "totalPages" => 1,
          "records" => [
            event(%{
              "files" => [
                file("/sports/UFC/Season 2025/UFC 311 Prelims.mkv"),
                file("/sports/UFC/Season 2025/UFC 311 Main Card.mkv"),
                file("/elsewhere/UFC 311.mkv"),
                %{"filePath" => "/sports/UFC/gone.mkv", "exists" => false}
              ]
            }),
            event(%{"id" => 61, "externalId" => "ev-028134"})
          ]
        }
      })

      assert [
               %Candidate{
                 path: "/data/sports/UFC/Season 2025/UFC 311 Prelims.mkv",
                 media_type: :sports_event,
                 identity: %SportsEventIdentity{sportarr_id: "ev-028133"}
               },
               %Candidate{path: "/data/sports/UFC/Season 2025/UFC 311 Main Card.mkv"}
             ] = Sportarr.scan(@servarr)
    end
  end

  describe "interpret_webhook/2" do
    test "imports a downloaded file and refreshes its request" do
      assert [
               {:ingest,
                [
                  %Candidate{
                    path: "/data/sports/UFC/UFC 311.mkv",
                    identity: %SportsEventIdentity{sportarr_id: "ev-028133"}
                  }
                ]},
               {:refresh_request, 60}
             ] =
               Sportarr.interpret_webhook(@servarr, %{
                 "eventType" => "Download",
                 "series" => %{"id" => 60, "externalId" => "ev-028133", "tsdbId" => "2179600"},
                 "episodeFile" => %{"path" => "/sports/UFC/UFC 311.mkv"}
               })
    end

    test "removes the deleted files' Media" do
      assert [{:remove_media, "/data/sports/UFC/UFC 311.mkv"}, {:refresh_request, 60}] =
               Sportarr.interpret_webhook(@servarr, %{
                 "eventType" => "EpisodeFileDelete",
                 "series" => %{"id" => 60, "externalId" => "ev-028133"},
                 "deletedFiles" => [%{"path" => "/sports/UFC/UFC 311.mkv"}]
               })
    end

    test "imports the renamed event's files again and drops its Media that are gone" do
      stub_sportarr(%{
        {"GET", "/api/events/60"} => event(%{"files" => [file("/sports/UFC/UFC 311 (2025).mkv")]})
      })

      assert [
               {:ingest, [%Candidate{path: "/data/sports/UFC/UFC 311 (2025).mkv"}]},
               {:remove_missing_media, identity}
             ] =
               Sportarr.interpret_webhook(@servarr, %{
                 "eventType" => "Rename",
                 "series" => %{"id" => 60, "externalId" => "ev-028133"}
               })

      assert identity == ContentIdentity.for_sports_event("ev-028133")
    end

    test "forgets the request of a deleted event" do
      assert [{:forget_request, 60}] =
               Sportarr.interpret_webhook(@servarr, %{
                 "eventType" => "SeriesDelete",
                 "series" => %{"id" => 60}
               })
    end
  end

  describe "submit_request/2" do
    setup do
      Req.Test.stub(WatchClub.Integrations.SportarrHub, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "idEvent" => "ev-028133",
              "strEvent" => "UFC 311 Makhachev vs Moicano",
              "strTimestamp" => "2025-01-19T01:00:00+00:00",
              "idLeague" => "lg-000079",
              "strLeague" => "UFC",
              "strSport" => "Combat",
              "strSeason" => "2025"
            }
          ]
        })
      end)

      %{content: generate(sports_event(external_id: "ev-028133")) |> Ash.load!(:implementation)}
    end

    test "adds the missing league without downloading its events, then requests the event", %{
      content: content
    } do
      stub_sportarr(%{
        {"GET", "/api/leagues"} => [],
        {"GET", "/api/v3/rootfolder"} => [%{"id" => 7, "path" => "/sports/"}],
        {"POST", "/api/leagues"} => fn conn ->
          assert %{
                   "externalId" => "lg-000079",
                   "name" => "UFC",
                   "sport" => "Combat",
                   "rootFolderId" => 7,
                   "monitorType" => "None"
                 } = conn.body_params

          %{"id" => 3}
        end,
        {"POST", "/api/events"} => fn conn ->
          assert %{
                   "externalId" => "ev-028133",
                   "leagueId" => 3,
                   "monitored" => true,
                   "searchOnAdd" => true
                 } = conn.body_params

          %{"id" => 60}
        end
      })

      assert {:ok, 60} = Sportarr.submit_request(@servarr, content)
    end

    test "follows and searches the event Sportarr already has", %{content: content} do
      test_pid = self()

      stub_sportarr(%{
        {"GET", "/api/leagues"} => [%{"id" => 1, "externalId" => "lg-000079"}],
        {"POST", "/api/events"} => %{"alreadyAdded" => true, "event" => %{"id" => 60}},
        {"PUT", "/api/events/60"} => fn conn ->
          send(test_pid, {:updated, conn.body_params})
          %{"id" => 60}
        end,
        {"POST", "/api/event/60/automatic-search"} => fn _conn ->
          send(test_pid, :searched)
          %{}
        end
      })

      assert {:ok, 60} = Sportarr.submit_request(@servarr, content)
      assert_received {:updated, %{"monitored" => true}}
      assert_received :searched
    end
  end

  describe "request_state/2" do
    test "is downloading with the progress of the event's download" do
      stub_sportarr(%{
        {"GET", "/api/events/60"} => event(%{}),
        {"GET", "/api/queue"} => [
          %{"eventId" => 61, "status" => 4, "progress" => 0},
          %{"eventId" => 60, "status" => 1, "progress" => 42.5}
        ]
      })

      assert {:downloading, 42.5} = Sportarr.request_state(@servarr, 60)
    end

    test "is downloaded once Sportarr has the event's files" do
      stub_sportarr(%{
        {"GET", "/api/events/60"} => event(%{"hasFile" => true}),
        {"GET", "/api/queue"} => []
      })

      assert {:downloaded, 100.0} = Sportarr.request_state(@servarr, 60)
    end

    test "is not released before the event" do
      stub_sportarr(%{
        {"GET", "/api/events/60"} => event(%{"eventDate" => "2999-01-01T00:00:00Z"}),
        {"GET", "/api/queue"} => []
      })

      assert {:not_released, +0.0} = Sportarr.request_state(@servarr, 60)
    end

    test "needs attention when its download failed" do
      stub_sportarr(%{
        {"GET", "/api/events/60"} => event(%{}),
        {"GET", "/api/queue"} => [%{"eventId" => 60, "status" => 4, "progress" => 10}]
      })

      assert {:needs_attention, 10.0} = Sportarr.request_state(@servarr, 60)
    end
  end
end
