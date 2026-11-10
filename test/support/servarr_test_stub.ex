defmodule WatchClub.Integrations.Servarr.TestStub do
  @moduledoc """
  Test-only Plug that fakes the Servarr (Radarr / Sonarr / Sportarr) API so the whole
  request lifecycle — adding a Source, submitting a request, and refreshing it —
  runs without a live server.

  Wired into `Req` globally from `config/test.exs` via
  `:watch_club, :servarr_req_options`, so every test gets a working Servarr with
  no setup. All endpoints require an `x-api-key` header (absence yields 401) and
  default to a "happy path": a just-added movie/series is still searching — no
  file yet, empty download queue.

  Tests that need a specific *arr state (a download in progress, a failure, ...)
  swap the plug for `{Req.Test, Servarr.Client}` and register a `Req.Test.stub/2`
  — see `WatchClub.Requests.MediaSourceRequestTest`.

  The optional `app_name` plug opt (default `"Radarr"`) is echoed on
  `/system/status` so a connection check's flavor assertion can be exercised.
  """
  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  # ── Connection + Add Source flow ──────────────────────────────────

  @impl true
  def call(%Plug.Conn{request_path: "/api/v3/system/status"} = conn, opts) do
    app_name = Keyword.get(opts, :app_name, "Radarr")

    ok(conn, %{
      "appName" => app_name,
      "version" => "5.4.6.8723",
      "instanceName" => "#{app_name} (Test Stub)"
    })
  end

  def call(%Plug.Conn{request_path: "/api/v3/qualityprofile"} = conn, _opts) do
    ok(conn, [
      %{"id" => 1, "name" => "Any"},
      %{"id" => 4, "name" => "HD-720p"},
      %{"id" => 6, "name" => "HD-1080p"},
      %{"id" => 7, "name" => "HD-1080p Bluray"},
      %{"id" => 8, "name" => "Ultra-HD"}
    ])
  end

  def call(%Plug.Conn{request_path: "/api/v3/rootfolder"} = conn, _opts) do
    ok(conn, [
      %{"path" => "/movies", "accessible" => true, "freeSpace" => 1_300_000_000_000},
      %{"path" => "/tv", "accessible" => true, "freeSpace" => 1_300_000_000_000},
      %{"path" => "/movies-4k", "accessible" => true, "freeSpace" => 640_000_000_000},
      %{"path" => "/movies-archive", "accessible" => true, "freeSpace" => 120_000_000_000}
    ])
  end

  def call(%Plug.Conn{request_path: "/api/v3/notification", method: "POST"} = conn, _opts),
    do: ok(conn, %{"id" => :erlang.unique_integer([:positive])})

  def call(%Plug.Conn{request_path: "/api/v3/notification/test", method: "POST"} = conn, _opts),
    do: ok(conn, %{})

  def call(
        %Plug.Conn{path_info: ["api", "v3", "notification", _id], method: "DELETE"} = conn,
        _opts
      ),
      do: ok(conn, %{})

  # Sportarr keeps WatchClub's webhook in its own notifications API
  def call(%Plug.Conn{request_path: "/api/notification", method: "POST"} = conn, _opts),
    do: ok(conn, %{"id" => :erlang.unique_integer([:positive])})

  def call(%Plug.Conn{request_path: "/api/notification/test", method: "POST"} = conn, _opts),
    do: ok(conn, %{"success" => true})

  def call(%Plug.Conn{path_info: ["api", "notification", _id], method: "DELETE"} = conn, _opts),
    do: ok(conn, %{})

  # ── Request + download flow (Radarr) ──────────────────────────────
  # Empty library → adopt finds nothing, so the caller adds the movie; the added
  # movie then reads as searching (no file yet) with an empty queue.

  def call(%Plug.Conn{request_path: "/api/v3/movie", method: "GET"} = conn, _opts),
    do: ok(conn, [])

  def call(%Plug.Conn{request_path: "/api/v3/movie", method: "POST"} = conn, _opts),
    do: ok(conn, %{"id" => :erlang.unique_integer([:positive])})

  def call(%Plug.Conn{path_info: ["api", "v3", "movie", _id], method: "GET"} = conn, _opts),
    do: ok(conn, %{"hasFile" => false, "isAvailable" => true})

  # ── Request + download flow (Sonarr) ──────────────────────────────

  def call(%Plug.Conn{request_path: "/api/v3/series/lookup"} = conn, _opts),
    do: ok(conn, [])

  def call(%Plug.Conn{request_path: "/api/v3/series", method: "GET"} = conn, _opts),
    do: ok(conn, [])

  def call(%Plug.Conn{request_path: "/api/v3/series", method: "POST"} = conn, _opts),
    do: ok(conn, %{"id" => :erlang.unique_integer([:positive])})

  def call(%Plug.Conn{request_path: "/api/v3/episode", method: "GET"} = conn, _opts),
    do: ok(conn, [])

  # ── Shared ────────────────────────────────────────────────────────

  def call(%Plug.Conn{request_path: "/api/v3/queue/details"} = conn, _opts),
    do: ok(conn, [])

  def call(%Plug.Conn{request_path: "/api/v3/command", method: "POST"} = conn, _opts),
    do: ok(conn, %{"id" => :erlang.unique_integer([:positive]), "status" => "queued"})

  def call(conn, _opts), do: json(conn, 404, %{"message" => "Not Found"})

  # Servarr requires an api key on every call; absence is a 401.
  defp ok(conn, body) do
    if has_api_key?(conn) do
      json(conn, 200, body)
    else
      json(conn, 401, %{"message" => "Unauthorized"})
    end
  end

  defp has_api_key?(conn) do
    case Plug.Conn.get_req_header(conn, "x-api-key") do
      [key | _] when is_binary(key) and byte_size(key) > 0 -> true
      _ -> false
    end
  end

  defp json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end
end
