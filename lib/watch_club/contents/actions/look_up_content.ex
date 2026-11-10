defmodule WatchClub.Contents.Actions.LookUpContent do
  @moduledoc """
  Finds the Movie or TV Show with a TMDB ID, as a `SearchResult` saying whether it's in the
  Library, without saving it. Returns nil when TMDB has none.
  """
  use Ash.Resource.Actions.Implementation

  alias WatchClub.Contents
  alias WatchClub.Contents.{ContentIdentity, SearchResult}
  alias WatchClub.Integrations.Tmdb

  @impl true
  def run(%Ash.ActionInput{arguments: %{content_identity: identity}}, _opts, context) do
    case fetch(identity, context.actor.settings.locale) do
      {:ok, result} -> {:ok, %{result | has_media?: in_library?(identity, context)}}
      {:error, :not_found} -> {:ok, nil}
      {:error, error} -> {:error, error}
    end
  end

  defp fetch(%ContentIdentity{type: :movie, external_id: id} = identity, locale) do
    with {:ok, movie} <- Tmdb.get_movie_details(id, locale: locale) do
      {:ok,
       %SearchResult{
         identity: identity,
         title: movie.title,
         year: movie.release_date && movie.release_date.year,
         overview: movie.overview,
         poster_path: movie.poster_path
       }}
    end
  end

  defp fetch(%ContentIdentity{type: :tv_show, external_id: id} = identity, locale) do
    with {:ok, tv_show} <- Tmdb.get_tv_details(id, locale: locale) do
      {:ok,
       %SearchResult{
         identity: identity,
         title: tv_show.name,
         year: tv_show.first_air_date && tv_show.first_air_date.year,
         overview: tv_show.overview,
         poster_path: tv_show.poster_path
       }}
    end
  end

  defp in_library?(identity, context) do
    [identity]
    |> Contents.get_contents_by_identities!(
      Ash.Context.to_opts(context, query: [filter: [has_media?: true]])
    )
    |> Enum.any?()
  end
end
