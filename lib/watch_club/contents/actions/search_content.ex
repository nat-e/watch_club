defmodule WatchClub.Contents.Actions.SearchContent do
  @moduledoc """
  Searches one scope on its Metadata Provider: Movies and TV Shows on TMDB, Sports
  Events on sportarr.net. With `has_media?`, searches only the Library's titles in
  that scope. Returns a `SearchResultsPage` of `SearchResult`s, each saying whether
  it's in the Library, and the pagination metadata.
  """
  use Ash.Resource.Actions.Implementation

  require Logger

  alias WatchClub.Contents
  alias WatchClub.Contents.{ContentIdentity, SearchContentType, SearchResult, SearchResultsPage}
  alias WatchClub.Contents.SportsEvent
  alias WatchClub.Integrations.SportarrHub
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.Integrations.Tmdb.{MovieSearchResult, TvSearchResult}

  # As many as a TMDB page
  @library_page_size 20

  @impl true
  def run(
        %Ash.ActionInput{
          arguments: %{query: query, content_type: scope, page: page, has_media?: true}
        },
        _opts,
        context
      ) do
    library_page =
      Contents.get_contents_in_library!(
        %{query: query},
        Ash.Context.to_opts(context,
          query: [filter: [type: [in: SearchContentType.content_types(scope)]]],
          page: [limit: @library_page_size, offset: (page - 1) * @library_page_size, count: true],
          load: [:implementation]
        )
      )

    {:ok,
     %SearchResultsPage{
       results: Enum.map(library_page.results, &library_search_result/1),
       page: page,
       total_pages: ceil(library_page.count / @library_page_size)
     }}
  end

  def run(
        %Ash.ActionInput{
          arguments: %{
            query: query,
            content_type: :movies_and_shows,
            page: page,
            has_media?: false
          }
        },
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
       results: put_has_media!(results, context),
       page: response.page,
       total_pages: response.total_pages
     }}
  end

  # sportarr.net returns every match at once, so there is a single page.
  def run(
        %Ash.ActionInput{
          arguments: %{query: query, content_type: :sports_events, has_media?: false}
        },
        _opts,
        context
      ) do
    Logger.info("Searching \"#{query}\" on sportarr.net",
      event: :search_sports_events,
      query: query
    )

    with {:ok, events} <- SportarrHub.search_events(query) do
      results =
        Enum.map(events, fn event ->
          %SearchResult{
            identity: ContentIdentity.for_sports_event(event.id),
            title: event.title,
            year: event.date && event.date.year,
            overview: event.overview,
            poster_path: event.poster_url
          }
        end)

      {:ok,
       %SearchResultsPage{results: put_has_media!(results, context), page: 1, total_pages: 1}}
    end
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

  defp put_has_media!(results, context) do
    with_media =
      results
      |> Enum.map(& &1.identity)
      |> Contents.get_contents_by_identities!(
        Ash.Context.to_opts(context, query: [filter: [has_media?: true]])
      )
      |> MapSet.new(&ContentIdentity.from_content/1)

    Enum.map(results, &%{&1 | has_media?: MapSet.member?(with_media, &1.identity)})
  end

  defp library_search_result(%{implementation: %SportsEvent{} = event} = content) do
    %SearchResult{
      identity: ContentIdentity.from_content(content),
      title: event.title,
      year: content.release_date && content.release_date.year,
      overview: event.overview,
      poster_path: event.poster_url,
      has_media?: true
    }
  end

  defp library_search_result(content) do
    localization = content.implementation.best_localization

    %SearchResult{
      identity: ContentIdentity.from_content(content),
      title: localization.title,
      year: content.release_date && content.release_date.year,
      overview: localization.overview,
      poster_path: localization.poster_path,
      has_media?: true
    }
  end
end
