defmodule WatchClub.Contents.Actions.SearchContent do
  @moduledoc """
  Searches Movies and TV Shows on TMDB.
  Returns a `SearchResultsPage` of `SearchResult`s, each with the actor's clubs that already have
  it, and the provider's pagination metadata.
  """
  use Ash.Resource.Actions.Implementation

  require Logger

  alias WatchClub.Clubs
  alias WatchClub.Contents.{ContentIdentity, SearchResult, SearchResultsPage}
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
    results = Enum.flat_map(response.results, &search_result/1)

    Logger.info("Found #{length(results)} results for \"#{query}\"",
      event: :search_movies_and_shows_found,
      query: query,
      page: page,
      num_results: length(results),
      total_results: length(response.results)
    )

    {:ok,
     %SearchResultsPage{
       results: put_clubs!(results, context),
       page: response.page,
       total_pages: response.total_pages
     }}
  end

  defp search_result(%MovieSearchResult{} = movie) do
    [
      %SearchResult{
        identity: ContentIdentity.for_movie(movie.id),
        title: movie.title,
        year: movie.release_date && movie.release_date.year,
        overview: movie.overview,
        poster_path: movie.poster_path
      }
    ]
  end

  defp search_result(%TvSearchResult{} = tv_show) do
    [
      %SearchResult{
        identity: ContentIdentity.for_tv_show(tv_show.id),
        title: tv_show.name,
        year: tv_show.first_air_date && tv_show.first_air_date.year,
        overview: tv_show.overview,
        poster_path: tv_show.poster_path
      }
    ]
  end

  # People aren't Content
  defp search_result(_other), do: []

  defp put_clubs!(results, context) do
    clubs_by_identity =
      results
      |> Enum.map(& &1.identity)
      |> Clubs.get_library_items_by_identities!(load: [:content, library: :club], scope: context)
      |> Enum.group_by(&ContentIdentity.from_content(&1.content), & &1.library.club)

    Enum.map(results, fn result ->
      %{
        result
        | clubs: clubs_by_identity |> Map.get(result.identity, []) |> Enum.uniq_by(& &1.id)
      }
    end)
  end
end
