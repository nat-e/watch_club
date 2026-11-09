defmodule WatchClub.MediaSources.Import.Ingestor.MatchContent do
  @moduledoc """
  Try to match a Candidate to a Content, using the main metadata provider
  (TMDB for movies/shows, Hardcover for books).

  We try to match with the following strategy
  - If we have the main provider ID, match with that
  - If not, try to match with other IDs (IMDB, TVDB, ...)
  - If not, fuzzy match with title + year

  Missing Content or TV Show Episodes fail the Oban job so it can retry.
  """

  alias WatchClub.Contents
  alias WatchClub.Contents.{ContentIdentity, TvShowEpisode}
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.MediaSources.Import.Candidate

  alias WatchClub.MediaSources.Import.Candidate.{
    BookIdentity,
    EpisodeIdentity,
    MatchResult,
    MovieIdentity
  }

  alias WatchClub.SystemActor

  require Logger

  # A Media Import refreshes the Content it matches when its metadata is older than 15 minutes.
  @metadata_max_age 15 * 60

  def apply(%Candidate{} = candidate) do
    Logger.info("Matching content for #{candidate.path} -- #{inspect(candidate.identity)}",
      event: :matching_candidate_started,
      identity: candidate.identity
    )

    case find_content!(candidate.identity) do
      nil ->
        Logger.warning("No match found for #{candidate.path}",
          event: :no_match_found
        )

        %{candidate | match_result: %MatchResult{result: :not_matched, matched_id: nil}}

      match ->
        Logger.info("#{candidate.path} matched to: #{to_string(match)}",
          event: :match_found,
          external_id: match.id,
          name: to_string(match)
        )

        %{candidate | match_result: %MatchResult{result: :success, matched_id: match.id}}
    end
  end

  # 1. Match by TMDB ID
  defp find_content!(%MovieIdentity{tmdb_id: tmdb_id}) when is_integer(tmdb_id) do
    Contents.get_or_refresh_content!(
      ContentIdentity.for_movie(tmdb_id),
      %{max_age: @metadata_max_age},
      actor: SystemActor.actor()
    )
  end

  # 2. Match by IMDB ID. We just fetch the TMDB ID and go back to step 1.
  defp find_content!(%MovieIdentity{imdb_id: imdb_id}) when is_binary(imdb_id) do
    Tmdb.find_by_external_id!(imdb_id, :imdb_id).movie_results
    |> List.first()
    |> then(fn
      nil -> nil
      result -> find_content!(%MovieIdentity{tmdb_id: result.id})
    end)
  end

  # 3. Match by title and year. We just fetch the TMDB ID and go back to step 1.
  defp find_content!(%MovieIdentity{title: title, year: year})
       when is_binary(title) and is_integer(year) do
    Tmdb.search_movie!(title, year: year).results
    |> List.first()
    |> then(fn
      nil -> nil
      result -> find_content!(%MovieIdentity{tmdb_id: result.id})
    end)
  end

  # TV Shows
  # 1. Match by TMDB ID
  defp find_content!(%EpisodeIdentity{
         tmdb_id: tmdb_id,
         season_number: season_number,
         episode_number: episode_number
       })
       when is_integer(tmdb_id) do
    content =
      Contents.get_or_refresh_content!(
        ContentIdentity.for_tv_show(tmdb_id),
        %{max_age: @metadata_max_age},
        actor: SystemActor.actor(),
        load: [implementation: %{load: [tv_show: [:episodes]]}]
      )

    Enum.find(
      content.implementation.episodes,
      &(&1.season_number == season_number and &1.episode_number == episode_number)
    ) ||
      raise "TV Show Episode #{TvShowEpisode.format_number(season_number, episode_number)} for TMDB TV Show #{tmdb_id} is still missing after fetching metadata"
  end

  # 2. Match by TVDB ID. We just fetch the TMDB ID and go back to step 1.
  defp find_content!(%EpisodeIdentity{tvdb_id: tvdb_id} = identity)
       when is_integer(tvdb_id) do
    find_show_by_external_id!(:tvdb_id, tvdb_id, identity)
  end

  # 3. Match by IMDB ID. We just fetch the TMDB ID and go back to step 1.
  defp find_content!(%EpisodeIdentity{imdb_id: imdb_id} = identity)
       when is_binary(imdb_id) do
    find_show_by_external_id!(:imdb_id, imdb_id, identity)
  end

  # 4. Match by title. We just fetch the TMDB ID and go back to step 1.
  defp find_content!(%EpisodeIdentity{title: title} = identity)
       when is_binary(title) do
    Tmdb.search_tv!(title).results
    |> List.first()
    |> then(fn
      nil -> nil
      result -> find_content!(%{identity | tmdb_id: result.id})
    end)
  end

  # Books
  defp find_content!(%BookIdentity{}) do
    raise "Not implemented"
  end

  defp find_content!(_identity), do: nil

  defp find_show_by_external_id!(source, external_id, %EpisodeIdentity{} = identity) do
    Tmdb.find_by_external_id!(external_id, source).tv_results
    |> List.first()
    |> then(fn
      nil -> nil
      result -> find_content!(%EpisodeIdentity{identity | tmdb_id: result.id})
    end)
  end
end
