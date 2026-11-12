defmodule WatchClub.MediaSources.Import.Ingestor.EpisodeParts do
  @moduledoc """
  Finds the Parts of TV Show Episodes a file holds, from the episodes its source lists for it.

  Sonarr numbers episodes like TVDB, which splits some episodes that TMDB lists as one, so the
  numbers can drift apart. Each source episode is matched to a TMDB episode, in this order:

  1. the same number, if the titles match;
  2. the same title, if they aired within a day of each other;
  3. the episode TMDB links to its TVDB id;
  4. the same number.

  Titles are compared without case, punctuation, a leading "The" or a part marker like "(2)". A
  source episode found by its title, whose title ends with "(2)" or "Part 2" while the TMDB title
  doesn't, is Part 2 of it: "Fun Run (2)" is Part 2 of "Fun Run". Any other match is Part 1.
  """

  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.MediaSources.Import.Candidate.EpisodeIdentity.Episode
  alias WatchClub.MediaSources.Import.TvShowEpisodeNotListedError

  @part_marker ~r/\s*(?:[\(\[]\s*(?:part\s*)?(\d+)\s*[\)\]]|[,:\-–]?\s*part\s+(\d+))\s*$/iu

  @doc """
  Returns the Parts a file holds, as `%{tv_show_episode_id: id, number: number}` maps, in order.
  Pass the TV Show's `episodes` with their `localizations`, its TMDB id, and the file's
  `source_episodes` in their source's order.

  Raises `TvShowEpisodeNotListedError` when a source episode matches none.
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
      # A part marker here ends a story told over two differently titled episodes, so it's Part 1
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

  # Sonarr's titles are in English, so compare with the English title, else any
  defp title(%TvShowEpisode{localizations: localizations}) do
    Enum.find_value(localizations, &(&1.iso_639_1 == "en" && &1.title)) ||
      Enum.find_value(localizations, & &1.title)
  end

  # Returns the title to compare, normalized, and the number of its part marker or nil
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
