defmodule WatchClub.Integrations.Servarr.Client do
  @moduledoc """
  HTTP transport and shared endpoints for the Servarr (Radarr / Sonarr) v3
  API. Flavor-agnostic: the only env it reads is `:servarr_req_options`
  (shared `Req` overrides, e.g. a test stub), so it never needs to know
  which product it is talking to.

  The endpoints that are byte-identical across products (`system/status`,
  `qualityprofile`, `rootfolder`) live here so the `Radarr` / `Sonarr`
  facades delegate rather than duplicate. Notification endpoints take a
  prebuilt body because the webhook payload's event flags differ by flavor
  — the facades build that. The facades also own their catalog endpoints
  (`/movie` vs `/series` + `/episode`).

  Every function takes a `base_url` normalized as `NormalizeUrl` stores it.
  Failures return `{:error, t:error/0}`. Requests are not retried, so the
  setup wizard answers quickly. Jobs rely on Oban for retries.
  """
  require Logger

  alias WatchClub.Integrations.Servarr.{QualityProfile, RootFolder, System}

  @timeout 5_000

  @typedoc """
  Why a request failed:

    * `:connection_failed` — the server could not be reached (refused, DNS,
      timeout, TLS...)
    * `:invalid_request`, `:unauthorized`, `:not_found`, `:rate_limited`,
      `:client_error`, `:server_error` — the server answered with an error status
    * `:unknown_error` — any other failure, such as malformed JSON
  """
  @type error ::
          :connection_failed
          | :invalid_request
          | :unauthorized
          | :not_found
          | :rate_limited
          | :client_error
          | :server_error
          | :unknown_error

  # ── Shared high-level endpoints ───────────────────────────────────

  @doc """
  Fetches `/api/v3/system/status`. Returns the parsed `System`, or
  `:invalid_response` when the server answers with something other than a
  JSON object, such as a web page.
  """
  @spec get_status(String.t(), String.t()) ::
          {:ok, System.t()} | {:error, error() | :invalid_response}
  def get_status(base_url, api_key) do
    case get(base_url, api_key, "/api/v3/system/status") do
      {:ok, body} when is_map(body) -> {:ok, System.from_api(body)}
      {:ok, _not_an_object} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @doc "Returns the quality profiles defined on the server."
  @spec list_quality_profiles(String.t(), String.t()) ::
          {:ok, [QualityProfile.t()]} | {:error, error()}
  def list_quality_profiles(base_url, api_key) do
    case get(base_url, api_key, "/api/v3/qualityprofile") do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &QualityProfile.from_api/1)}
      {:error, _} = error -> error
    end
  end

  @doc "Returns the root folders configured on the server."
  @spec list_root_folders(String.t(), String.t()) ::
          {:ok, [RootFolder.t()]} | {:error, error()}
  def list_root_folders(base_url, api_key) do
    case get(base_url, api_key, "/api/v3/rootfolder") do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &RootFolder.from_api/1)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Asks the server to fire a `Test` event against the supplied webhook
  config. The server calls the callback URL right away and only returns 200
  if it answered with a 2xx. Nothing is persisted, so the test body needs no
  event flags.

  Returns `:webhook_unreachable` when the callback failed: the server
  answers 400 when the callback URL returned an error, and 500 when it
  could not reach it. A callback URL that never answers keeps the server
  waiting for 100 s, so a timeout counts as unreachable too: the server
  itself answered the previous wizard step moments before. These are user
  mistakes, so they are only logged as warnings.
  """
  @spec test_notification(String.t(), String.t(), String.t(), map()) ::
          {:ok, :verified} | {:error, error() | :webhook_unreachable}
  def test_notification(base_url, api_key, notifications_path, body) do
    base_url
    |> new_request(api_key)
    |> Req.post(url: "#{notifications_path}/test", json: body)
    |> case do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, :verified}

      {:ok, %Req.Response{status: status, body: body}} when status in [400, 500] ->
        Logger.warning("Servarr — Webhook test failed",
          event: :servarr_api_error,
          status: status,
          error: body
        )

        {:error, :webhook_unreachable}

      {:error, %Req.TransportError{reason: :timeout}} ->
        Logger.warning("Servarr — Webhook test timed out", event: :servarr_api_error)
        {:error, :webhook_unreachable}

      response ->
        handle_response(response)
    end
  end

  @doc """
  Creates a persistent notification from the app's `body`. Radarr and Sonarr
  run their own `Test` step before persisting, so a successful response means
  the callback URL was reachable at registration time.
  """
  @spec create_notification(String.t(), String.t(), String.t(), map()) ::
          {:ok, %{id: integer()}} | {:error, error()}
  def create_notification(base_url, api_key, notifications_path, body) do
    case post(base_url, api_key, notifications_path, body) do
      {:ok, %{"id" => id}} when is_integer(id) -> {:ok, %{id: id}}
      {:error, _} = error -> error
    end
  end

  @doc """
  Updates an existing notification in place via PUT, from the app's `body`.
  Radarr and Sonarr re-run their `Test` step before persisting, so a
  successful response means the new URL was reachable.
  """
  @spec update_notification(String.t(), String.t(), String.t(), integer(), map()) ::
          {:ok, %{id: integer()}} | {:error, error()}
  def update_notification(base_url, api_key, notifications_path, notification_id, body)
      when is_integer(notification_id) do
    body = Map.put(body, :id, notification_id)

    case put(base_url, api_key, "#{notifications_path}/#{notification_id}", body) do
      {:ok, %{"id" => id}} when is_integer(id) -> {:ok, %{id: id}}
      {:error, _} = error -> error
    end
  end

  @doc """
  Deletes a notification by its server id. A 404 is treated as success so
  the operation stays idempotent.
  """
  @spec delete_notification(String.t(), String.t(), String.t(), integer()) ::
          {:ok, :deleted} | {:error, error()}
  def delete_notification(base_url, api_key, notifications_path, notification_id)
      when is_integer(notification_id) do
    case delete(base_url, api_key, "#{notifications_path}/#{notification_id}") do
      {:ok, _body} -> {:ok, :deleted}
      {:error, :not_found} -> {:ok, :deleted}
      {:error, _} = error -> error
    end
  end

  @doc """
  Asks the server to pull download progress from its download client now,
  instead of waiting for its periodic "Refresh Monitored Downloads" task
  (nominally ~1 min, in practice often 90–120s). The command runs
  asynchronously server-side but completes within ~1s, and the server
  coalesces duplicate concurrent commands — so callers can fire it freely
  without coordinating. Identical endpoint on Radarr and Sonarr.
  """
  @spec refresh_monitored_downloads(String.t(), String.t()) :: {:ok, :queued} | {:error, error()}
  def refresh_monitored_downloads(base_url, api_key) do
    case post(base_url, api_key, "/api/v3/command", %{"name" => "RefreshMonitoredDownloads"}) do
      {:ok, _body} -> {:ok, :queued}
      {:error, _} = error -> error
    end
  end

  # ── Transport ─────────────────────────────────────────────────────

  @spec request(String.t(), String.t(), keyword()) :: {:ok, any()} | {:error, error()}
  def request(base_url, api_key, opts) do
    base_url
    |> new_request(api_key)
    |> Req.request(opts)
    |> handle_response()
  end

  @spec get(String.t(), String.t(), String.t(), keyword()) :: {:ok, any()} | {:error, error()}
  def get(base_url, api_key, path, opts \\ []) do
    request(base_url, api_key, [method: :get, url: path] ++ opts)
  end

  @spec post(String.t(), String.t(), String.t(), map(), keyword()) ::
          {:ok, any()} | {:error, error()}
  def post(base_url, api_key, path, body, opts \\ []) do
    request(base_url, api_key, [method: :post, url: path, json: body] ++ opts)
  end

  @spec put(String.t(), String.t(), String.t(), map(), keyword()) ::
          {:ok, any()} | {:error, error()}
  def put(base_url, api_key, path, body, opts \\ []) do
    request(base_url, api_key, [method: :put, url: path, json: body] ++ opts)
  end

  @spec delete(String.t(), String.t(), String.t(), keyword()) :: {:ok, any()} | {:error, error()}
  def delete(base_url, api_key, path, opts \\ []) do
    request(base_url, api_key, [method: :delete, url: path] ++ opts)
  end

  defp new_request(base_url, api_key) do
    [
      base_url: base_url,
      headers: [{"x-api-key", api_key}, {"accept", "application/json"}],
      retry: false,
      connect_options: [timeout: @timeout],
      receive_timeout: @timeout,
      compressed: true
    ]
    |> Req.new(Application.get_env(:watch_club, :servarr_req_options, []))
    |> OpentelemetryReq.attach()
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %Req.Response{status: 400, body: body}}) do
    Logger.error("Servarr — Invalid Request", event: :servarr_api_error, status: 400, error: body)

    {:error, :invalid_request}
  end

  defp handle_response({:ok, %Req.Response{status: 401, body: body}}) do
    Logger.warning("Servarr — Unauthorized", event: :servarr_api_error, status: 401, error: body)

    {:error, :unauthorized}
  end

  defp handle_response({:ok, %Req.Response{status: 404, body: body}}) do
    Logger.warning("Servarr — Not Found", event: :servarr_api_error, status: 404, error: body)
    {:error, :not_found}
  end

  defp handle_response({:ok, %Req.Response{status: 429, body: body}}) do
    Logger.warning("Servarr — Rate limited", event: :servarr_api_error, status: 429, error: body)
    {:error, :rate_limited}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 400..499 do
    Logger.warning("Servarr — Client error #{status}",
      event: :servarr_api_error,
      status: status,
      error: body
    )

    {:error, :client_error}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 500..599 do
    Logger.warning("Servarr — Server error #{status}",
      event: :servarr_api_error,
      status: status,
      error: body
    )

    {:error, :server_error}
  end

  defp handle_response({:error, %Req.TransportError{} = error}) do
    Logger.warning("Servarr — Connection failed", event: :servarr_api_error, error: error)
    {:error, :connection_failed}
  end

  defp handle_response({:error, reason}) do
    Logger.error("Servarr — Unknown error",
      event: :servarr_api_error,
      error: reason
    )

    {:error, :unknown_error}
  end
end
