defmodule WatchClub.Integrations.Tmdb.Client do
  alias OpenTelemetry.SemConv.Incubating.URLAttributes

  require Logger

  # 1 day
  @default_cache_ttl_ms 24 * 60 * 60 * 1000

  @spec request(keyword()) :: {:ok, term()} | {:error, any()}
  def request(opts) do
    # Returned the cached response if present unless cache is de-activated
    with true <- Keyword.get(opts, :cache, true),
         {:ok, resp} when not is_nil(resp) <- Cachex.get(:tmdb_api_cache, cache_key(opts)) do
      {:ok, resp}
    else
      _ -> send_request(opts)
    end
  end

  defp send_request(opts) do
    [
      base_url: "https://api.themoviedb.org/3",
      retry: :transient,
      max_retries: 3,
      receive_timeout: 5_000,
      compressed: true,
      # Spans and metrics name requests after their path template, which Req keeps only with path_params
      path_params: []
    ]
    |> Req.new(Application.get_env(:watch_club, :tmdb_req_options, []))
    |> OpentelemetryReq.attach(opt_in_attrs: [URLAttributes.url_template()])
    |> ReqTele.attach(pipeline: false)
    # :cache and :cache_ttl are this client's options, not Req's
    |> Req.request(Keyword.drop(opts, [:cache, :cache_ttl]))
    |> handle_response(opts)
  end

  def get(path, opts \\ []), do: request([method: :get, url: path] ++ opts)
  def post(path, body, opts \\ []), do: request([method: :post, url: path, json: body] ++ opts)

  defp handle_response({:ok, %Req.Response{status: status, body: body}}, opts)
       when status in 200..299 do
    if Keyword.get(opts, :cache, true) do
      Logger.debug("TMDB Cache miss - caching response")

      Cachex.put(:tmdb_api_cache, cache_key(opts), body,
        expire: Keyword.get(opts, :cache_ttl, @default_cache_ttl_ms)
      )
    end

    {:ok, body}
  end

  defp handle_response({:ok, %Req.Response{status: 404, body: body}}, _opts) do
    Logger.warning("TMDB — Not Found", event: :tmdb_api_error, status: 404, error: body)
    {:error, :not_found}
  end

  defp handle_response({:ok, %Req.Response{status: 429, body: body}}, _opts) do
    Logger.warning("TMDB — Rate limited", event: :tmdb_api_error, status: 429, error: body)
    {:error, :rate_limited}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}, _opts)
       when status in 400..499 do
    Logger.warning("TMDB — Client error #{status}",
      event: :tmdb_api_error,
      status: status,
      error: body
    )

    {:error, :client_error}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}, _opts)
       when status in 500..599 do
    Logger.warning("TMDB — Server error #{status}",
      event: :tmdb_api_error,
      status: status,
      error: body
    )

    {:error, :server_error}
  end

  # Expected, like the other TMDB failures: a warning, which Sentry doesn't report as an error
  defp handle_response({:error, reason}, _opts) do
    Logger.warning("TMDB — Unknown error",
      event: :tmdb_error,
      error: reason
    )

    {:error, :unknown_error}
  end

  # Templates need their path params as well as order-independent query params to identify a response.
  defp cache_key(opts) do
    {
      Keyword.fetch!(opts, :url),
      Enum.sort(Keyword.get(opts, :path_params, [])),
      Enum.sort(Keyword.get(opts, :params, []))
    }
  end
end
