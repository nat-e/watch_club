defmodule WatchClub.Integrations.Tmdb do
  import WatchClub.Integrations.Tmdb.Client

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

  @spec search_movie(String.t(), year: pos_integer(), page: pos_integer(), locale: atom()) ::
          {:ok, MovieSearchResponse.t()} | {:error, term()}
  def search_movie(query, opts \\ []) do
    case request(
           url: "/search/movie",
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

  @spec search_tv(String.t(), year: pos_integer(), page: pos_integer(), locale: atom()) ::
          {:ok, TvSearchResponse.t()} | {:error, term()}
  def search_tv(query, opts \\ []) do
    case request(
           url: "/search/tv",
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

  @spec find_by_external_id(String.t(), :imdb_id | :tvdb_id) ::
          {:ok, FindByExternalIdResponse.t()} | {:error, term()}
  def find_by_external_id(external_id, source) when source in [:imdb_id, :tvdb_id] do
    case request(
           url: "/find/#{external_id}",
           params: [external_source: Atom.to_string(source)]
         ) do
      {:ok, body} -> {:ok, FindByExternalIdResponse.from_api(body)}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_movie_details(integer() | String.t(), locale: atom()) ::
          {:ok, MovieDetailsResponse.t()} | {:error, term()}
  def get_movie_details(tmdb_id, opts \\ []) do
    case request(
           url: "/movie/#{tmdb_id}",
           params: [
             language: format_language(opts[:locale]),
             append_to_response: "translations,images,credits,videos"
           ]
         ) do
      {:ok, body} -> {:ok, MovieDetailsResponse.from_api(body)}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_tv_details(integer() | String.t(), locale: atom()) ::
          {:ok, TvDetailsResponse.t()} | {:error, term()}
  def get_tv_details(tmdb_id, opts \\ []) do
    case request(
           url: "/tv/#{tmdb_id}",
           params: [
             language: format_language(opts[:locale]),
             append_to_response: "translations,images,external_ids,credits,videos"
           ]
         ) do
      {:ok, body} -> {:ok, TvDetailsResponse.from_api(body)}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_tv_season_details(integer() | String.t(), integer(), locale: atom()) ::
          {:ok, TvDetailsResponse.SeasonDetails.t()} | {:error, term()}
  def get_tv_season_details(tmdb_id, season_number, opts \\ []) do
    case request(
           url: "/tv/#{tmdb_id}/season/#{season_number}",
           params: [language: format_language(opts[:locale])]
         ) do
      {:ok, body} -> {:ok, TvDetailsResponse.SeasonDetails.from_api(body)}
      {:error, error} -> {:error, error}
    end
  end

  defp format_language(nil), do: nil

  defp format_language(locale) do
    locale |> Atom.to_string() |> String.replace("_", "-")
  end
end
