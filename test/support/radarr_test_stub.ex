defmodule WatchClub.Integrations.Radarr.TestStub do
  @moduledoc """
  Test-only Plug that fakes Radarr's v3 API so the Add Radarr Source flow
  can be exercised without a live Radarr instance.

  Wired into `Req` from `config/test.exs` via
  `:watch_club, :radarr_req_options, plug: {…, []}`.

  Returns canned responses for the three endpoints Watch Club calls
  during the create flow:

    * `GET /api/v3/system/status`
    * `GET /api/v3/qualityprofile`
    * `GET /api/v3/rootfolder`

  All three require an `x-api-key` header; absence yields a 401. Tests
  that need custom responses should swap the plug for
  `{Req.Test, WatchClub.Integrations.Radarr.Client}` and register a
  `Req.Test.stub/2` in their setup.
  """
  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{request_path: "/api/v3/system/status"} = conn, _opts) do
    if has_api_key?(conn) do
      json(conn, 200, %{
        "version" => "5.4.6.8723",
        "instanceName" => "Radarr (Test Stub)"
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

  def call(%Plug.Conn{path_info: ["api", "v3", "notification", _id], method: "DELETE"} = conn, _opts) do
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
