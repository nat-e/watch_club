defmodule WatchClub.MediaSources.Import.Ingestor.MatchContent do
  @moduledoc """
  Try to match a Candidate to a Content, using the main metadata provider
  (TMDB for movies/shows, sportarr.net for Sports Events, Hardcover for books).

  We try to match with the following strategy
  - If the file's Media has a Manual Match, keep it
  - If we have the main provider ID, match with that
  - If not, try to match with other IDs (IMDB, TVDB, ...)
  - If not, fuzzy match with title, and year when known

  A Movie or Sports Event file gets Part 1 of its match. A TV Show Episode file gets the Parts
  `EpisodeParts` finds, and is unmatched when TMDB doesn't list one of its TV Show Episodes.
  """

  alias WatchClub.Contents
  alias WatchClub.Contents.ContentIdentity
  alias WatchClub.Integrations.SportarrHub
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.MediaCatalog
  alias WatchClub.MediaCatalog.Media
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Ingestor.EpisodeParts

  alias WatchClub.MediaSources.Import.Candidate.{
    BookIdentity,
    EpisodeIdentity,
    MatchResult,
    MovieIdentity,
    SportsEventIdentity
  }

  alias WatchClub.SystemActor

  # A Media Import refreshes the Content it matches when its metadata is older than 15 minutes.
  @metadata_max_age 15 * 60

  def apply!(%Candidate{} = candidate) do
    match_result =
      case manual_match(candidate) do
        [] -> match_automatically!(candidate.identity)
        parts -> %MatchResult{result: :matched, reason: :manual_match, parts: parts}
      end

    %{candidate | match_result: match_result}
  end

  # The Parts the file's Video holds when it has a Manual Match, else []
  defp manual_match(%Candidate{media_source_id: media_source_id, path: path}) do
    case MediaCatalog.get_media_by_path(media_source_id, path,
           load: [video: :parts],
           actor: SystemActor.actor()
         ) do
      {:ok, %Media{manually_matched?: true, video: %{parts: parts}}} ->
        Enum.map(
          parts,
          &Map.take(&1, [:movie_id, :tv_show_episode_id, :sports_event_id, :number, :name])
        )

      {:ok, %Media{}} ->
        []

      {:error, %Ash.Error.Invalid{}} ->
        []
    end
  end

  defp match_automatically!(identity) do
    content = find_content!(identity)
    parts = content && parts!(content, identity)

    cond do
      is_nil(content) -> %MatchResult{result: :unmatched, reason: :content_not_found}
      is_nil(parts) -> %MatchResult{result: :unmatched, reason: :episode_not_listed}
      true -> %MatchResult{result: :matched, parts: parts}
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
  defp find_content!(%EpisodeIdentity{tmdb_id: tmdb_id}) when is_integer(tmdb_id) do
    Contents.get_or_refresh_content!(
      ContentIdentity.for_tv_show(tmdb_id),
      %{max_age: @metadata_max_age},
      actor: SystemActor.actor(),
      load: [implementation: %{load: [tv_show: [episodes: :localizations]]}]
    )
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
    |> String.split()
    # Drops separators such as "-", so they don't count as words
    |> Enum.filter(&String.match?(&1, ~r/[[:alnum:]]/u))
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

  # Movies, TV Shows and Sports Events share the id of their Content
  defp parts!(content, %MovieIdentity{}), do: [%{movie_id: content.id, number: 1}]
  defp parts!(content, %SportsEventIdentity{}), do: [%{sports_event_id: content.id, number: 1}]

  defp parts!(%{implementation: tv_show}, %EpisodeIdentity{episodes: episodes}),
    do: EpisodeParts.find!(tv_show.episodes, tv_show.tmdb_id, episodes)

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
