defmodule WatchClub.Contents.Actions.SearchContent do
  @moduledoc """
  Searches content on external APIs (TMDB for Movies/Shows and Hardcover for books).
  Returns a `SearchResultsPage` of MovieSearchResult/TvSearchResult with the
  provider's pagination metadata.
  """
  use Ash.Resource.Actions.Implementation

  require Logger

  alias WatchClub.Contents.SearchResultsPage
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.Integrations.Tmdb.{MovieSearchResult, TvSearchResult}

  @impl true
  def run(
        %Ash.ActionInput{arguments: %{query: query, content_type: :movies_and_shows, page: page}},
        _opts,
        context
      ) do
    Logger.info("Searching \"#{query}\" on TMDB (page #{page})",
      event: :search_movies_and_shows,
      query: query,
      page: page
    )

    response = Tmdb.search_multi!(query, page: page, locale: context.actor.settings.locale)

    results =
      response.results
      |> Enum.filter(&(is_struct(&1, MovieSearchResult) || is_struct(&1, TvSearchResult)))

    num_results = length(results)

    Logger.info("Found #{num_results} results for \"#{query}\"",
      event: :search_movies_and_shows_found,
      query: query,
      page: page,
      num_results: num_results,
      total_results: length(response.results)
    )

    {:ok,
     %SearchResultsPage{
       results: results,
       page: response.page,
       total_pages: response.total_pages
     }}
  end

  def run(
        %Ash.ActionInput{arguments: %{content_type: :books}},
        _opts,
        _context
      ) do
    raise "Not implemented"
  end
end
