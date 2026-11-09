defmodule WatchClub.Integrations.Tmdb.ClientTest do
  use WatchClub.DataCase, async: false

  alias WatchClub.Integrations.Tmdb.Client

  describe "request/1" do
    test "keeps different TMDB IDs in separate cache entries and does not count cache hits" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:watch_club, :tmdb, :request, :stop]])
      on_exit(fn -> :telemetry.detach(ref) end)

      Req.Test.stub(Client, fn conn ->
        Req.Test.json(conn, %{"id" => conn.request_path |> Path.basename() |> String.to_integer()})
      end)

      for id <- [11, 12] do
        assert {:ok, %{"id" => ^id}} = Client.request(url: "/movie/:id", path_params: [id: id])

        assert_received {[:watch_club, :tmdb, :request, :stop], ^ref, %{duration: duration},
                         %{endpoint: "/movie/:id", status: "2xx"}}

        assert duration > 0
      end

      Req.Test.stub(Client, fn _conn -> flunk("a cache hit must not make an HTTP request") end)

      for id <- [11, 12] do
        assert {:ok, %{"id" => ^id}} = Client.request(url: "/movie/:id", path_params: [id: id])
      end

      refute_received {[:watch_club, :tmdb, :request, :stop], ^ref, _, _}
    end
  end
end
