defmodule WatchClub.Integrations.Radarr.Client do
  @moduledoc """
  HTTP transport for Radarr's v3 API.
  """
  require Logger

  alias WatchClub.Shared.Url

  @receive_timeout 5_000

  @spec request(String.t(), String.t(), keyword()) :: {:ok, any()} | {:error, term()}
  def request(base_url, api_key, opts) do
    # User-visible actions (Add Radarr Source) want fast feedback over
    # silent retries — `retry: false`. Background import flows can opt in
    # by passing `retry: :transient` through `opts`.
    [
      base_url: Url.normalize_base(base_url),
      headers: [{"x-api-key", api_key}, {"accept", "application/json"}],
      retry: false,
      receive_timeout: @receive_timeout
    ]
    |> Keyword.merge(Application.get_env(:watch_club, :radarr_req_options, []))
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

  @spec delete(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, any()} | {:error, term()}
  def delete(base_url, api_key, path, opts \\ []) do
    request(base_url, api_key, [method: :delete, url: path] ++ opts)
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %Req.Response{status: 401, body: body}}) do
    Logger.warning("Radarr — Unauthorized: #{inspect(body)}")
    {:error, :unauthorized}
  end

  defp handle_response({:ok, %Req.Response{status: 404, body: body}}) do
    Logger.warning("Radarr — Not Found: #{inspect(body)}")
    {:error, :not_found}
  end

  defp handle_response({:ok, %Req.Response{status: 429, body: body}}) do
    Logger.warning("Radarr — Rate limited: #{inspect(body)}")
    {:error, :rate_limited}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 400..499 do
    Logger.warning("Radarr — Client error #{status}: #{inspect(body)}")
    {:error, :client_error}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 500..599 do
    Logger.warning("Radarr — Server error #{status}: #{inspect(body)}")
    {:error, :server_error}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
    Logger.warning("Radarr — Unexpected status #{status}: #{inspect(body)}")
    {:error, :unexpected_status}
  end

  defp handle_response({:error, %Req.TransportError{reason: reason}}) do
    Logger.warning("Radarr — Transport error: #{inspect(reason)}")
    {:error, {:transport_error, reason}}
  end

  defp handle_response({:error, reason}) do
    Logger.warning("Radarr — Unknown error: #{inspect(reason)}")
    {:error, :unknown_error}
  end
end
