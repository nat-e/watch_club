defmodule WatchClub.Integrations.Tmdb.Client do
  require Logger

  @spec request(keyword()) :: {:ok, Req.Response.t()} | {:error, any()}
  def request(opts) do
    IO.inspect(Application.get_env(:watch_club, :tmdb_req_options, []))

    [
      base_url: "https://api.themoviedb.org/3",
      retry: :transient,
      max_retries: 3,
      receive_timeout: 5_000
    ]
    |> Keyword.merge(Application.get_env(:watch_club, :tmdb_req_options, []))
    |> Req.new()
    |> Req.request(opts)
    |> handle_response()
  end

  def get(path, opts \\ []), do: request([method: :get, url: path] ++ opts)
  def post(path, body, opts \\ []), do: request([method: :post, url: path, json: body] ++ opts)

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}

  defp handle_response({:ok, %Req.Response{status: 400, body: body}}) do
    Logger.error("TMDB - Invalid Request: #{inspect(body)}")
    {:error, :invalid_request}
  end

  defp handle_response({:ok, %Req.Response{status: 401, body: body}}) do
    Logger.error("TMDB - Unauthorized Request: #{inspect(body)}")
    {:error, :unauthorized}
  end

  defp handle_response({:ok, %Req.Response{status: 404, body: body}}) do
    Logger.error("TMDB - Not Found: #{inspect(body)}")
    {:error, :not_found}
  end

  defp handle_response({:ok, %Req.Response{status: 429, body: body}}) do
    Logger.warning("TMDB - Rate Limit error: #{inspect(body)}")
    {:error, :rate_limited}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
    Logger.warning("TMDB - Server error (#{status}): #{inspect(body)}")
    {:error, :server_error}
  end

  defp handle_response({:error, %Req.TransportError{reason: reason}}) do
    Logger.warning("TMDB - Transport error: #{inspect(reason)}")
    {:error, {:transport_error}}
  end

  defp handle_response({:error, reason}) do
    Logger.warning("TMDB - Unknown error: #{inspect(reason)}")
    {:error, :unknown_error}
  end
end
