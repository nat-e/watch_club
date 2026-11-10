defmodule WatchClub.MediaSources.Import.Ingestor.MatchContent do
  @moduledoc """
  Try to match a Candidate to a Content, using the main metadata provider
  (TMDB for movies/shows, sportarr.net for Sports Events, Hardcover for books).

  We try to match with the following strategy
  - If the file's Media has a Manual Match, keep it
  - If we have the main provider ID, match with that
  - If not, try to match with other IDs (IMDB, TVDB, ...)
  - If not, fuzzy match with title, and year when known

  Missing Content or TV Show Episodes fail the Oban job so it can retry.
  """

  alias WatchClub.Contents
  alias WatchClub.Contents.{ContentIdentity, TvShowEpisode}
  alias WatchClub.Integrations.SportarrHub
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.MediaCatalog
  alias WatchClub.MediaCatalog.Media
  alias WatchClub.MediaSources.Import.{Candidate, TvShowEpisodeNotListedError}

  alias WatchClub.MediaSources.Import.Candidate.{
    BookIdentity,
    EpisodeIdentity,
    MatchResult,
    MovieIdentity,
    SportsEventIdentity
  }

  alias WatchClub.SystemActor

  require Logger

  # A Media Import refreshes the Content it matches when its metadata is older than 15 minutes.
  @metadata_max_age 15 * 60

  def apply!(%Candidate{} = candidate) do
    case manual_match(candidate.path) do
      nil ->
        match_automatically!(candidate)

      matched_id ->
        Logger.info("#{candidate.path} keeps its Manual Match", event: :manual_match_kept)
        %{candidate | match_result: %MatchResult{result: :success, matched_id: matched_id}}
    end
  end

  # The Movie, TV Show Episode or Sports Event of the Video's Manual Match
  defp manual_match(path) do
    case MediaCatalog.get_media_by_path(path, load: :video, actor: SystemActor.actor()) do
      {:ok, %Media{manually_matched?: true, video: video}} ->
        video.movie_id || video.tv_show_episode_id || video.sports_event_id

      {:ok, %Media{}} ->
        nil

      {:error, %Ash.Error.Invalid{}} ->
        nil
    end
  end

  defp match_automatically!(candidate) do
    Logger.info("Matching content for #{candidate.path} -- #{inspect(candidate.identity)}",
      event: :matching_candidate_started,
      identity: candidate.identity
    )

    case find_content!(candidate.identity) do
      nil ->
        Logger.warning("No match found for #{candidate.path}",
          event: :no_match_found
        )

        :telemetry.execute([:watch_club, :media_import, :match], %{count: 1}, %{
          result: :not_matched
        })

        %{candidate | match_result: %MatchResult{result: :not_matched, matched_id: nil}}

      match ->
        Logger.info("#{candidate.path} matched to: #{to_string(match)}",
          event: :match_found,
          external_id: match.id,
          name: to_string(match)
        )

        :telemetry.execute([:watch_club, :media_import, :match], %{count: 1}, %{result: :matched})
        %{candidate | match_result: %MatchResult{result: :success, matched_id: match.id}}
    end
  rescue
    error in TvShowEpisodeNotListedError ->
      episode = TvShowEpisode.format_number(error.season_number, error.episode_number)

      Logger.warning(
        "TV Show Episode #{episode} for TMDB TV Show #{error.tmdb_id} is not listed for #{candidate.path}",
        event: :tv_show_episode_not_listed,
        path: candidate.path,
        tmdb_id: error.tmdb_id,
        episode: episode
      )

      :telemetry.execute(
        [:watch_club, :media_import, :match],
        %{count: 1},
        %{result: :episode_not_listed}
      )

      reraise error, __STACKTRACE__
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

  # 3. Match by title, and year when known. We just fetch the TMDB ID and go back to step 1.
  defp find_content!(%MovieIdentity{title: title, year: year}) when is_binary(title) do
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
      raise TvShowEpisodeNotListedError,
        tmdb_id: tmdb_id,
        season_number: season_number,
        episode_number: episode_number
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

  # Sports Events
  # 1. Match by Sportarr ID
  defp find_content!(%SportsEventIdentity{sportarr_id: sportarr_id})
       when is_binary(sportarr_id) do
    Contents.get_or_refresh_content!(
      ContentIdentity.for_sports_event(sportarr_id),
      %{max_age: @metadata_max_age},
      actor: SystemActor.actor()
    )
  end

  # 2. Match by title, and year when known. We just fetch the Sportarr ID and go back to step 1.
  defp find_content!(%SportsEventIdentity{title: title, year: year}) when is_binary(title) do
    title
    |> String.split(~r/[^[:alnum:]]+/u, trim: true)
    |> search_sports_event!(year)
    |> then(fn
      nil -> nil
      event -> find_content!(%SportsEventIdentity{sportarr_id: event.id})
    end)
  end

  # Books
  defp find_content!(%BookIdentity{}) do
    raise "Not implemented"
  end

  defp find_content!(_identity), do: nil

  # sportarr.net only finds titles with every word, but file names add words such as
  # "Prelims". Drops the last word until events match, and keeps the match only when
  # it is a single event of that year: shorter titles, such as "Formula 1", match
  # other events. Two words at least, so "UFC" alone doesn't match any UFC event.
  defp search_sports_event!(words, _year) when length(words) < 2, do: nil

  defp search_sports_event!(words, year) do
    {:ok, events} = SportarrHub.search_events(Enum.join(words, " "))

    case Enum.filter(events, &(is_nil(year) or (&1.date && &1.date.year == year))) do
      [event] -> event
      [] -> search_sports_event!(Enum.drop(words, -1), year)
      _ambiguous -> nil
    end
  end

  defp find_show_by_external_id!(source, external_id, %EpisodeIdentity{} = identity) do
    Tmdb.find_by_external_id!(external_id, source).tv_results
    |> List.first()
    |> then(fn
      nil -> nil
      result -> find_content!(%EpisodeIdentity{identity | tmdb_id: result.id})
    end)
  end
end
