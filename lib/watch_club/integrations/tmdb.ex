defmodule WatchClub.Integrations.Tmdb do
  import WatchClub.Integrations.Tmdb.Client

  alias WatchClub.Accounts.UserLocale

  alias WatchClub.Integrations.Tmdb.{
    FindByExternalIdResponse,
    MovieDetailsResponse,
    MovieSearchResponse,
    MovieSearchResult,
    PersonSearchResult,
    TvDetailsResponse,
    TvSearchResponse,
    TvSearchResult
  }

  @type search_result :: MovieSearchResult.t() | TvSearchResult.t() | PersonSearchResult.t()

  defmodule MultiSearchResponse do
    @moduledoc false
    alias WatchClub.Integrations.Tmdb.{MovieSearchResult, PersonSearchResult, TvSearchResult}

    @type t :: %__MODULE__{
            page: pos_integer(),
            results: [WatchClub.Integrations.Tmdb.search_result()],
            total_pages: non_neg_integer(),
            total_results: non_neg_integer()
          }

    defstruct [:page, :results, :total_pages, :total_results]

    @spec from_api(map()) :: t()
    def from_api(data) do
      %__MODULE__{
        page: data["page"],
        results: parse_results(data["results"] || []),
        total_pages: data["total_pages"],
        total_results: data["total_results"]
      }
    end

    defp parse_results(items) do
      Enum.flat_map(items, fn
        %{"media_type" => "movie"} = item -> [MovieSearchResult.from_api(item)]
        %{"media_type" => "tv"} = item -> [TvSearchResult.from_api(item)]
        %{"media_type" => "person"} = item -> [PersonSearchResult.from_api(item)]
        _ -> []
      end)
    end
  end

  @spec search_multi(String.t(), page: pos_integer(), locale: :atom) ::
          {:ok, MultiSearchResponse.t()} | {:error, term()}
  def search_multi(query, opts \\ []) do
    page = opts[:page] || 1

    case request(
           url: "/search/multi",
           path_params: [],
           params: [
             query: query,
             page: page,
             include_adult: false,
             language: format_language(opts[:locale])
           ]
         ) do
      {:ok, body} -> {:ok, MultiSearchResponse.from_api(body)}
      {:error, error} -> {:error, error}
    end
  end

  @spec search_multi!(String.t(), page: pos_integer(), locale: :atom) :: MultiSearchResponse.t()
  def search_multi!(query, opts \\ []) do
    {:ok, response} = search_multi(query, opts)
    response
  end

  @spec search_movie(String.t(), year: pos_integer(), page: pos_integer(), locale: atom()) ::
          {:ok, MovieSearchResponse.t()} | {:error, term()}
  def search_movie(query, opts \\ []) do
    case request(
           url: "/search/movie",
           path_params: [],
           params:
             [
               query: query,
               page: opts[:page] || 1,
               include_adult: false,
               language: format_language(opts[:locale])
             ] ++ if(opts[:year], do: [primary_release_year: opts[:year]], else: [])
         ) do
      {:ok, body} -> {:ok, MovieSearchResponse.from_api(body)}
      {:error, error} -> {:error, error}
    end
  end

  @spec search_movie!(String.t(), year: pos_integer(), page: pos_integer(), locale: atom()) ::
          MovieSearchResponse.t()
  def search_movie!(query, opts \\ []) do
    {:ok, results} = search_movie(query, opts)
    results
  end

  @spec search_tv(String.t(), year: pos_integer(), page: pos_integer(), locale: atom()) ::
          {:ok, TvSearchResponse.t()} | {:error, term()}
  def search_tv(query, opts \\ []) do
    case request(
           url: "/search/tv",
           path_params: [],
           params:
             [
               query: query,
               page: opts[:page] || 1,
               include_adult: false,
               language: format_language(opts[:locale])
             ] ++ if(opts[:year], do: [first_air_date_year: opts[:year]], else: [])
         ) do
      {:ok, body} -> {:ok, TvSearchResponse.from_api(body)}
      {:error, error} -> {:error, error}
    end
  end

  @spec search_tv!(String.t(), year: pos_integer(), page: pos_integer(), locale: atom()) ::
          TvSearchResponse.t()
  def search_tv!(query, opts \\ []) do
    {:ok, response} = search_tv(query, opts)
    response
  end

  @spec find_by_external_id(String.t(), :imdb_id | :tvdb_id) ::
          {:ok, FindByExternalIdResponse.t()} | {:error, term()}
  def find_by_external_id(external_id, source) when source in [:imdb_id, :tvdb_id] do
    case request(
           url: "/find/:external_id",
           path_params: [external_id: external_id],
           params: [external_source: Atom.to_string(source)]
         ) do
      {:ok, body} -> {:ok, FindByExternalIdResponse.from_api(body)}
      {:error, error} -> {:error, error}
    end
  end

  @spec find_by_external_id!(String.t(), :imdb_id | :tvdb_id) :: FindByExternalIdResponse.t()
  def find_by_external_id!(external_id, source) do
    {:ok, response} = find_by_external_id(external_id, source)
    response
  end

  @spec get_movie_details(integer() | String.t(), locale: atom(), cache: boolean()) ::
          {:ok, MovieDetailsResponse.t()} | {:error, term()}
  def get_movie_details(tmdb_id, opts \\ []) do
    case request(
           url: "/movie/:id",
           path_params: [id: tmdb_id],
           params: [
             language: format_language(opts[:locale]),
             append_to_response: "translations,images,credits,videos",
             include_image_language: image_languages()
           ],
           cache: Keyword.get(opts, :cache, true)
         ) do
      {:ok, body} -> {:ok, MovieDetailsResponse.from_api(body)}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_movie_details!(integer() | String.t(), locale: atom(), cache: boolean()) ::
          MovieDetailsResponse.t()
  def get_movie_details!(tmdb_id, opts \\ []) do
    {:ok, response} = get_movie_details(tmdb_id, opts)
    response
  end

  @spec get_tv_details(integer() | String.t(), locale: atom(), cache: boolean()) ::
          {:ok, TvDetailsResponse.t()} | {:error, term()}
  def get_tv_details(tmdb_id, opts \\ []) do
    case request(
           url: "/tv/:id",
           path_params: [id: tmdb_id],
           params: [
             language: format_language(opts[:locale]),
             append_to_response: "translations,images,external_ids,credits,videos",
             include_image_language: image_languages()
           ],
           cache: Keyword.get(opts, :cache, true)
         ) do
      {:ok, body} -> {:ok, TvDetailsResponse.from_api(body)}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_tv_details!(integer() | String.t(), locale: atom(), cache: boolean()) ::
          TvDetailsResponse.t()
  def get_tv_details!(tmdb_id, opts \\ []) do
    {:ok, response} = get_tv_details(tmdb_id, opts)
    response
  end

  @spec get_tv_season_details(integer() | String.t(), integer(), locale: atom(), cache: boolean()) ::
          {:ok, TvDetailsResponse.SeasonDetails.t()} | {:error, term()}
  def get_tv_season_details(tmdb_id, season_number, opts \\ []) do
    case request(
           url: "/tv/:id/season/:season_number",
           path_params: [id: tmdb_id, season_number: season_number],
           params: [language: format_language(opts[:locale])],
           cache: Keyword.get(opts, :cache, true)
         ) do
      {:ok, body} -> {:ok, TvDetailsResponse.SeasonDetails.from_api(body)}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_tv_season_details!(integer() | String.t(), integer(),
          locale: atom(),
          cache: boolean()
        ) ::
          TvDetailsResponse.SeasonDetails.t()
  def get_tv_season_details!(tmdb_id, season_number, opts \\ []) do
    {:ok, details} = get_tv_season_details(tmdb_id, season_number, opts)
    details
  end

  # TMDB otherwise filters images by `language`: ask for every Locale's, and those without text
  defp image_languages do
    UserLocale.values()
    |> Enum.map(&(&1 |> UserLocale.split() |> List.first()))
    |> Enum.concat(["null"])
    |> Enum.uniq()
    |> Enum.join(",")
  end

  defp format_language(nil), do: nil

  defp format_language(locale) do
    locale |> Atom.to_string() |> String.replace("_", "-")
  end
end
