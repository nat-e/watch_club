defmodule WatchClub.Media.ImportPipeline.MatchContent do
  @moduledoc """
  Resolves a candidate's identity to a `Content` row, creating it if needed,
  and writes the resolved id back to the candidate as `:matched_id`.
  """

  @behaviour WatchClub.Media.ImportPipeline.Stage

  alias WatchClub.Contents
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.{BookIdentity, EpisodeIdentity, MovieIdentity}
  alias WatchClub.Media.ImportRun
  alias WatchClub.SystemActor

  require Logger

  @impl true
  def apply(%Candidate{} = candidate, %ImportRun{}) do
    case get_or_create_content(candidate.identity) do
      {:ok, match} ->
        {:ok, %{candidate | matched_id: match.id}}

      {:error, reason} ->
        Logger.error("Error matching content for #{candidate.path}: #{inspect(reason)}")
        {:halt, "Error matching content"}
    end
  end

  # 1. Match by TMDB ID
  defp get_or_create_content(%MovieIdentity{tmdb_id: tmdb_id}) when is_integer(tmdb_id) do
    Contents.get_or_create_movie(tmdb_id, SystemActor.actor())
  end

  # 2. Match by IMDB ID. We just fetch the TMDB ID and go back to step 1.
  defp get_or_create_content(%MovieIdentity{imdb_id: imdb_id}) when is_binary(imdb_id) do
    case Tmdb.find_by_external_id(imdb_id, :imdb_id) do
      {:ok,
       %Tmdb.FindByExternalIdResponse{movie_results: [%Tmdb.MovieSearchResult{} = result | _]}} ->
        get_or_create_content(%MovieIdentity{tmdb_id: result.id})

      {:ok, _} ->
        {:error, :no_match}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # 3. Match by title and year. We just fetch the TMDB ID and go back to step 1.
  defp get_or_create_content(%MovieIdentity{title: title, year: year})
       when is_binary(title) and is_integer(year) do
    case Tmdb.search_movie(title, year: year) do
      {:ok, %Tmdb.MovieSearchResponse{results: [%Tmdb.MovieSearchResult{} = result | _]}} ->
        get_or_create_content(%MovieIdentity{tmdb_id: result.id})

      {:ok, _} ->
        {:error, :no_match}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # TV Shows
  # 1. Match by TMDB ID
  defp get_or_create_content(%EpisodeIdentity{
         tmdb_id: tmdb_id,
         season_number: season_number,
         episode_number: episode_number
       })
       when is_integer(tmdb_id) do
    with {:ok, content} <- Contents.get_or_create_tv_show(tmdb_id, SystemActor.actor()) do
      case Enum.find(content.tv_show.episodes, fn e ->
             e.season_number == season_number and e.episode_number == episode_number
           end) do
        nil -> {:error, :no_match}
        episode -> {:ok, episode}
      end
    end
  end

  # 2. Match by TVDB ID. We just fetch the TMDB ID and go back to step 1.
  defp get_or_create_content(%EpisodeIdentity{tvdb_id: tvdb_id} = identity)
       when is_integer(tvdb_id) do
    find_show_by_external_id(:tvdb_id, tvdb_id, identity)
  end

  # 3. Match by IMDB ID. We just fetch the TMDB ID and go back to step 1.
  defp get_or_create_content(%EpisodeIdentity{imdb_id: imdb_id} = identity)
       when is_binary(imdb_id) do
    find_show_by_external_id(:imdb_id, imdb_id, identity)
  end

  # 4. Match by title. We just fetch the TMDB ID and go back to step 1.
  defp get_or_create_content(%EpisodeIdentity{title: title} = identity)
       when is_binary(title) do
    case Tmdb.search_tv(title) do
      {:ok, %Tmdb.TvSearchResponse{results: [%Tmdb.TvSearchResult{} = result | _]}} ->
        get_or_create_content(%{identity | tmdb_id: result.id})

      {:ok, _} ->
        {:error, :no_match}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Books
  defp get_or_create_content(%BookIdentity{}) do
    {:error, :not_implemented}
  end

  defp get_or_create_content(_identity), do: {:error, :no_match}

  defp find_show_by_external_id(source, external_id, %EpisodeIdentity{} = identity) do
    case Tmdb.find_by_external_id(external_id, source) do
      {:ok, %Tmdb.FindByExternalIdResponse{tv_results: [%Tmdb.TvSearchResult{} = result | _]}} ->
        get_or_create_content(%{identity | tmdb_id: result.id})

      {:ok, _} ->
        {:error, :no_match}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
