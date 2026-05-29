defmodule WatchClub.Integrations.Servarr.TestStub do
  @moduledoc """
  Test-only Plug that fakes the Servarr (Radarr / Sonarr) v3 API so the Add
  Source flow can be exercised without a live server.

  Wired into `Req` from `config/test.exs` via
  `:watch_club, :servarr_req_options`. The optional `app_name` plug opt
  (default `"Radarr"`) is echoed on `/system/status` so a connection
  check's flavor assertion can be exercised.

  Returns canned responses for the endpoints Watch Club calls during the
  create flow:

    * `GET /api/v3/system/status`
    * `GET /api/v3/qualityprofile`
    * `GET /api/v3/rootfolder`
    * webhook notification create / test / delete

  All require an `x-api-key` header; absence yields a 401. Tests that need
  custom responses should swap the plug for `{Req.Test, Servarr.Client}`
  and register a `Req.Test.stub/2` in their setup.
  """
  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{request_path: "/api/v3/system/status"} = conn, opts) do
    app_name = Keyword.get(opts, :app_name, "Radarr")

    if has_api_key?(conn) do
      json(conn, 200, %{
        "appName" => app_name,
        "version" => "5.4.6.8723",
        "instanceName" => "#{app_name} (Test Stub)"
      })
    else
      json(conn, 401, %{"message" => "Unauthorized"})
    end
  end

  def call(%Plug.Conn{request_path: "/api/v3/qualityprofile"} = conn, _opts) do
    if has_api_key?(conn) do
      json(conn, 200, [
        %{"id" => 1, "name" => "Any"},
        %{"id" => 4, "name" => "HD-720p"},
        %{"id" => 6, "name" => "HD-1080p"},
        %{"id" => 7, "name" => "HD-1080p Bluray"},
        %{"id" => 8, "name" => "Ultra-HD"}
      ])
    else
      json(conn, 401, %{"message" => "Unauthorized"})
    end
  end

  def call(%Plug.Conn{request_path: "/api/v3/rootfolder"} = conn, _opts) do
    if has_api_key?(conn) do
      json(conn, 200, [
        %{"path" => "/movies", "accessible" => true, "freeSpace" => 1_300_000_000_000},
        %{"path" => "/tv", "accessible" => true, "freeSpace" => 1_300_000_000_000},
        %{"path" => "/movies-4k", "accessible" => true, "freeSpace" => 640_000_000_000},
        %{"path" => "/movies-archive", "accessible" => true, "freeSpace" => 120_000_000_000}
      ])
    else
      json(conn, 401, %{"message" => "Unauthorized"})
    end
  end

  def call(%Plug.Conn{request_path: "/api/v3/notification", method: "POST"} = conn, _opts) do
    if has_api_key?(conn) do
      json(conn, 200, %{"id" => :erlang.unique_integer([:positive])})
    else
      json(conn, 401, %{"message" => "Unauthorized"})
    end
  end

  def call(%Plug.Conn{request_path: "/api/v3/notification/test", method: "POST"} = conn, _opts) do
    if has_api_key?(conn) do
      json(conn, 200, %{})
    else
      json(conn, 401, %{"message" => "Unauthorized"})
    end
  end

  def call(
        %Plug.Conn{path_info: ["api", "v3", "notification", _id], method: "DELETE"} = conn,
        _opts
      ) do
    if has_api_key?(conn) do
      json(conn, 200, %{})
    else
      json(conn, 401, %{"message" => "Unauthorized"})
    end
  end

  def call(conn, _opts), do: json(conn, 404, %{"message" => "Not Found"})

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
