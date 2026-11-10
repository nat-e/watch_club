defmodule WatchClub.Integrations.SportarrHub do
  @moduledoc """
  The Sportarr metadata service at sportarr.net, WatchClub's Metadata Provider for
  Sports Events. Its public API needs no key and limits each IP address: 300
  searches and 20 event lookups a minute. Req retries a `429` after its `Retry-After`.

  Results are never read, so no score or winner is stored.
  """

  require Logger

  # 1 day
  @cache_ttl_ms 24 * 60 * 60 * 1000

  defmodule Event do
    @moduledoc "A Sports Event on sportarr.net."

    @type t :: %__MODULE__{
            id: String.t(),
            title: String.t(),
            starts_at: DateTime.t() | nil,
            date: Date.t() | nil,
            league_id: String.t() | nil,
            league_name: String.t() | nil,
            sport: String.t() | nil,
            season: String.t() | nil,
            venue: String.t() | nil,
            country: String.t() | nil,
            overview: String.t() | nil,
            poster_url: String.t() | nil,
            backdrop_url: String.t() | nil
          }

    defstruct [
      :id,
      :title,
      :starts_at,
      :date,
      :league_id,
      :league_name,
      :sport,
      :season,
      :venue,
      :country,
      :overview,
      :poster_url,
      :backdrop_url
    ]

    @doc false
    def from_api(data) do
      %__MODULE__{
        id: data["idEvent"],
        title: data["strEvent"],
        starts_at: parse(data["strTimestamp"], &DateTime.from_iso8601/1),
        date: parse(data["dateEvent"], &Date.from_iso8601/1),
        league_id: presence(data["idLeague"]),
        league_name: presence(data["strLeague"]),
        sport: presence(data["strSport"]),
        season: presence(data["strSeason"]),
        venue: presence(data["strVenue"]),
        country: presence(data["strCountry"]),
        overview: presence(data["strDescriptionEN"]),
        poster_url: presence(data["strPoster"]),
        backdrop_url: presence(data["strFanart"])
      }
    end

    defp parse(value, parser) when is_binary(value) do
      case parser.(value) do
        {:ok, parsed, _offset} -> parsed
        {:ok, parsed} -> parsed
        {:error, _} -> nil
      end
    end

    defp parse(_value, _parser), do: nil

    defp presence(value) when is_binary(value) do
      case String.trim(value) do
        "" -> nil
        value -> value
      end
    end

    defp presence(_value), do: nil
  end

  @doc "The Sports Events whose title matches the query."
  @spec search_events(String.t()) :: {:ok, [Event.t()]} | {:error, term()}
  def search_events(query) do
    case request(url: "/api/v2/json/search/event/:query", path_params: [query: query]) do
      {:ok, %{"data" => %{"search" => events}}} when is_list(events) ->
        {:ok, Enum.map(events, &Event.from_api/1)}

      {:ok, _no_results} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "The Sports Event with this Sportarr ID, such as `ev-028133`."
  @spec get_event(String.t(), cache: boolean()) :: {:ok, Event.t()} | {:error, term()}
  def get_event(sportarr_id, opts \\ []) do
    case request(
           url: "/api/v2/json/lookup/event/:id",
           path_params: [id: sportarr_id],
           cache: Keyword.get(opts, :cache, true)
         ) do
      {:ok, %{"data" => [event | _]}} -> {:ok, Event.from_api(event)}
      {:ok, _no_event} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp request(opts) do
    {cache?, opts} = Keyword.pop(opts, :cache, true)
    key = {opts[:url], opts[:path_params]}

    case cache? && Cachex.get(:sportarr_hub_cache, key) do
      {:ok, body} when not is_nil(body) ->
        {:ok, body}

      _ ->
        with {:ok, body} <- send_request(opts) do
          Cachex.put(:sportarr_hub_cache, key, body, expire: @cache_ttl_ms)
          {:ok, body}
        end
    end
  end

  defp send_request(opts) do
    [base_url: "https://sportarr.net", retry: :transient, max_retries: 3, receive_timeout: 10_000]
    |> Req.new(Application.get_env(:watch_club, :sportarr_hub_req_options, []))
    |> Req.request(opts)
    |> case do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("Sportarr Hub — HTTP #{status}",
          event: :sportarr_hub_api_error,
          status: status,
          error: body
        )

        {:error, if(status == 404, do: :not_found, else: :http_error)}

      {:error, reason} ->
        Logger.warning("Sportarr Hub — request failed", event: :sportarr_hub_error, error: reason)
        {:error, :unknown_error}
    end
  end
end
