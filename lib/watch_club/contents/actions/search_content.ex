defmodule WatchClub.Contents.Actions.SearchContent do
  @moduledoc """
  Searches content on external APIs (TMDB for Movies/Shows and Hardcover for books).
  Returns a `SearchResultsPage` of MovieSearchResult/TvSearchResult with the
  provider's pagination metadata.
  """
  use Ash.Resource.Actions.Implementation

  require Logger
  require Ash.Query

  alias WatchClub.Contents.SearchResultsPage
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.Integrations.Tmdb.{MovieSearchResult, TvSearchResult}

  @impl true
  def run(
        %Ash.ActionInput{arguments: %{query: query, content_type: :movies_and_shows, page: page}},
        _opts,
        context
      ) do
    case Tmdb.search_multi(query, page: page, locale: context.actor.settings.locale) do
      {:ok, response} ->
        results =
          Enum.filter(
            response.results,
            &(is_struct(&1, MovieSearchResult) || is_struct(&1, TvSearchResult))
          )

        {:ok,
         %SearchResultsPage{
           results: results,
           page: response.page,
           total_pages: response.total_pages
         }}

      {:error, error} ->
        Logger.error("Error searching TMDB for `#{query}`: #{inspect(error)}")
        {:error, error}
    end
  end

  def run(
        %Ash.ActionInput{arguments: %{content_type: :books}},
        _opts,
        _context
      ) do
    {:ok, %SearchResultsPage{}}
  end
end
