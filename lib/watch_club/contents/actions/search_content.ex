defmodule WatchClub.Contents.Actions.SearchContent do
  @moduledoc """
  Searches content on external APIs (TMDB for Movies/Shows and Hardcover for books).
  This returns a list of MovieSearchResult/TvSearchResult
  """
  use Ash.Resource.Actions.Implementation

  require Logger
  require Ash.Query

  alias WatchClub.Integrations.Tmdb
  alias WatchClub.Integrations.Tmdb.{MovieSearchResult, TvSearchResult}

  @impl true
  def run(
        %Ash.ActionInput{arguments: %{query: query, content_type: :movies_and_shows}},
        _opts,
        context
      ) do
    case Tmdb.search_multi(query, locale: context.actor.settings.locale) do
      {:ok, response} ->
        {:ok,
         response.results
         |> Enum.filter(&(is_struct(&1, MovieSearchResult) || is_struct(&1, TvSearchResult)))}

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
    {:ok, []}
  end
end
