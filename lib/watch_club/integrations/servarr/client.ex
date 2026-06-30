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
  """
  require Logger

  alias WatchClub.Integrations.Servarr.{QualityProfile, RootFolder, System, Webhook}
  alias WatchClub.Shared.Path

  @receive_timeout 5_000

  # ── Shared high-level endpoints ───────────────────────────────────

  @doc """
  Fetches `/api/v3/system/status`. Returns the parsed `System`
  """
  @spec get_status(String.t(), String.t()) :: {:ok, System.t()} | {:error, term()}
  def get_status(base_url, api_key) do
    case get(base_url, api_key, "/api/v3/system/status") do
      {:ok, body} when is_map(body) -> {:ok, System.from_api(body)}
      {:error, _} = error -> error
    end
  end

  @doc "Returns the quality profiles defined on the server."
  @spec list_quality_profiles(String.t(), String.t()) ::
          {:ok, [QualityProfile.t()]} | {:error, term()}
  def list_quality_profiles(base_url, api_key) do
    case get(base_url, api_key, "/api/v3/qualityprofile") do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &QualityProfile.from_api/1)}
      {:error, _} = error -> error
    end
  end

  @doc "Returns the root folders configured on the server."
  @spec list_root_folders(String.t(), String.t()) ::
          {:ok, [RootFolder.t()]} | {:error, term()}
  def list_root_folders(base_url, api_key) do
    case get(base_url, api_key, "/api/v3/rootfolder") do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &RootFolder.from_api/1)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Asks the server to fire a `Test` event against the supplied webhook
  config. The server resolves the call synchronously and only returns 200
  if the callback URL answered with a 2xx. Nothing is persisted, so the
  test body needs no event flags.
  """
  @spec test_notification(String.t(), String.t(), Webhook.config()) ::
          {:ok, :verified} | {:error, term()}
  def test_notification(base_url, api_key, config) do
    case post(base_url, api_key, "/api/v3/notification/test", Webhook.body([], config)) do
      {:ok, _body} -> {:ok, :verified}
      {:error, _} = error -> error
    end
  end

  @doc """
  Creates a persistent notification subscribed to `event_flags` (the caller
  supplies the flavor's flags). The server runs its own `Test` step before
  persisting, so a successful response means the callback URL was reachable
  at registration time.
  """
  @spec create_notification(String.t(), String.t(), [atom()], Webhook.config()) ::
          {:ok, %{id: integer()}} | {:error, term()}
  def create_notification(base_url, api_key, event_flags, config) do
    case post(base_url, api_key, "/api/v3/notification", Webhook.body(event_flags, config)) do
      {:ok, %{"id" => id}} when is_integer(id) -> {:ok, %{id: id}}
      {:error, _} = error -> error
    end
  end

  @doc """
  Updates an existing notification in place via PUT, subscribed to
  `event_flags`. The server re-runs its `Test` step before persisting, so a
  successful response means the new URL was reachable.
  """
  @spec update_notification(String.t(), String.t(), [atom()], integer(), Webhook.config()) ::
          {:ok, %{id: integer()}} | {:error, term()}
  def update_notification(base_url, api_key, event_flags, notification_id, config)
      when is_integer(notification_id) do
    body = Map.put(Webhook.body(event_flags, config), :id, notification_id)

    case put(base_url, api_key, "/api/v3/notification/#{notification_id}", body) do
      {:ok, %{"id" => id}} when is_integer(id) -> {:ok, %{id: id}}
      {:error, _} = error -> error
    end
  end

  @doc """
  Deletes a notification by its server id. A 404 is treated as success so
  the operation stays idempotent.
  """
  @spec delete_notification(String.t(), String.t(), integer()) ::
          {:ok, :deleted} | {:error, term()}
  def delete_notification(base_url, api_key, notification_id)
      when is_integer(notification_id) do
    case delete(base_url, api_key, "/api/v3/notification/#{notification_id}") do
      {:ok, _body} -> {:ok, :deleted}
      {:error, :not_found} -> {:ok, :deleted}
      {:error, _} = error -> error
    end
  end

  # ── Transport ─────────────────────────────────────────────────────

  @spec request(String.t(), String.t(), keyword()) :: {:ok, any()} | {:error, term()}
  def request(base_url, api_key, opts) do
    [
      base_url: Path.normalize_base_url(base_url),
      headers: [{"x-api-key", api_key}, {"accept", "application/json"}],
      retry: :transient,
      receive_timeout: @receive_timeout,
      compressed: true
    ]
    |> Keyword.merge(Application.get_env(:watch_club, :servarr_req_options, []))
    |> Req.new()
    |> Req.request(opts)
    |> handle_response()
  end

  @spec get(String.t(), String.t(), String.t(), keyword()) :: {:ok, any()} | {:error, term()}
  def get(base_url, api_key, path, opts \\ []) do
    request(base_url, api_key, [method: :get, url: path] ++ opts)
  end

  @spec post(String.t(), String.t(), String.t(), map(), keyword()) ::
          {:ok, any()} | {:error, term()}
  def post(base_url, api_key, path, body, opts \\ []) do
    request(base_url, api_key, [method: :post, url: path, json: body] ++ opts)
  end

  @spec put(String.t(), String.t(), String.t(), map(), keyword()) ::
          {:ok, any()} | {:error, term()}
  def put(base_url, api_key, path, body, opts \\ []) do
    request(base_url, api_key, [method: :put, url: path, json: body] ++ opts)
  end

  @spec delete(String.t(), String.t(), String.t(), keyword()) :: {:ok, any()} | {:error, term()}
  def delete(base_url, api_key, path, opts \\ []) do
    request(base_url, api_key, [method: :delete, url: path] ++ opts)
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
       when status in 500..599 do
    Logger.warning("Servarr — Server error #{status}",
      event: :servarr_api_error,
      status: status,
      error: body
    )

    {:error, :server_error}
  end

  defp handle_response({:error, reason}) do
    Logger.error("Servarr — Unknown error",
      event: :servarr_api_error,
      error: reason
    )

    {:error, :unknown_error}
  end
end
