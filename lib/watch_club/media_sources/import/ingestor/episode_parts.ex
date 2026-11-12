defmodule WatchClub.MediaSources.Import.Ingestor.EpisodeParts do
  @moduledoc """
  The Parts a file holds of a TV Show's episodes, from the episodes its source says it holds.
  Sonarr numbers episodes like TVDB, which splits some episodes the Metadata Provider lists
  whole, so the numbers drift apart. Each source episode is the TV Show Episode:

  1. with its number, when their titles match;
  2. else with its title, aired within a day of it;
  3. else that TMDB links to its TVDB id;
  4. else with its number.

  Titles match without their case, punctuation, leading "The" and a part marker such as "(2)"
  or "Part 2", which must be the same when both titles have one. A source episode found by its
  title alone, whose title has a part marker that the TV Show Episode's title lacks, is that
  Part of it: "Fun Run (2)" is Part 2 of "Fun Run". Any other is Part 1. On an episode found by
  its number, a part marker rather means a story told over two episodes with different titles,
  such as "The One with the Morning After (2)".
  """

  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.MediaSources.Import.Candidate.EpisodeIdentity.Episode
  alias WatchClub.MediaSources.Import.TvShowEpisodeNotListedError

  @part_marker ~r/\s*(?:[\(\[]\s*(?:part\s*)?(\d+)\s*[\)\]]|[,:\-–]?\s*part\s+(\d+))\s*$/iu

  @doc """
  The Parts the file holds, as `%{tv_show_episode_id: id, number: number}`, among the
  `episodes` of the TV Show `tmdb_id`, loaded with their `localizations`. `source_episodes` are
  in their source's order. Raises `TvShowEpisodeNotListedError` when one of them matches none,
  so the file isn't saved and a later scan retries it.
  """
  @spec find!([TvShowEpisode.t()], integer(), [Episode.t()]) :: [map()]
  def find!(episodes, tmdb_id, source_episodes) do
    source_episodes
    |> Enum.map(fn source ->
      match!(source, episodes, tmdb_id) ||
        raise TvShowEpisodeNotListedError,
          tmdb_id: tmdb_id,
          season_number: source.season_number,
          episode_number: source.episode_number
    end)
    |> Enum.uniq_by(fn {episode, number} -> {episode.id, number} end)
    |> Enum.map(fn {episode, number} -> %{tv_show_episode_id: episode.id, number: number} end)
  end

  defp match!(%Episode{} = source, episodes, tmdb_id) do
    numbered =
      Enum.find(
        episodes,
        &(&1.season_number == source.season_number and &1.episode_number == source.episode_number)
      )

    cond do
      numbered && same_title?(source, numbered) ->
        {numbered, 1}

      titled = Enum.find(episodes, &(same_title?(source, &1) and aired_within_a_day?(source, &1))) ->
        {titled, part_number(source, titled)}

      linked = linked_to_tvdb_id!(source, episodes, tmdb_id) ->
        {linked, 1}

      numbered ->
        {numbered, 1}

      true ->
        nil
    end
  end

  defp same_title?(%Episode{title: nil}, _episode), do: false

  defp same_title?(%Episode{title: source_title}, episode) do
    {source_key, source_marker} = title_key(source_title)
    {key, marker} = title_key(title(episode))
    source_key == key and (is_nil(marker) or marker == source_marker)
  end

  defp part_number(%Episode{title: source_title}, episode) do
    case {title_key(source_title), title_key(title(episode))} do
      {{_source_key, number}, {_key, nil}} when is_integer(number) -> number
      _whole_or_split_alike -> 1
    end
  end

  defp aired_within_a_day?(
         %Episode{air_date: %Date{} = aired},
         %TvShowEpisode{air_date: %Date{}} = episode
       ),
       do: abs(Date.diff(aired, episode.air_date)) <= 1

  defp aired_within_a_day?(_source, _episode), do: false

  defp linked_to_tvdb_id!(%Episode{tvdb_id: tvdb_id}, episodes, tmdb_id)
       when is_integer(tvdb_id) do
    Tmdb.find_by_external_id!(tvdb_id, :tvdb_id).tv_episode_results
    |> Enum.find_value(fn result ->
      result.show_id == tmdb_id &&
        Enum.find(
          episodes,
          &(&1.season_number == result.season_number and
              &1.episode_number == result.episode_number)
        )
    end)
  end

  defp linked_to_tvdb_id!(_source, _episodes, _tmdb_id), do: nil

  # The English title, which Sonarr's are in, else any
  defp title(%TvShowEpisode{localizations: localizations}) do
    Enum.find_value(localizations, &(&1.iso_639_1 == "en" && &1.title)) ||
      Enum.find_value(localizations, & &1.title)
  end

  # What a title is compared by, and the number of its part marker or nil
  defp title_key(nil), do: {nil, nil}

  defp title_key(title) do
    number =
      case Regex.run(@part_marker, title, capture: :all_but_first) do
        nil -> nil
        captures -> captures |> Enum.find(&(&1 != "")) |> String.to_integer()
      end

    key =
      title
      |> String.replace(@part_marker, "")
      |> String.downcase()
      |> String.replace("&", "and")
      |> String.replace(~r/['’]s?\b/u, "")
      |> String.replace(~r/[^\p{L}\p{N}]+/u, " ")
      |> String.trim()
      |> String.replace(~r/^(the|a|an) /u, "")

    {key, number}
  end
end
