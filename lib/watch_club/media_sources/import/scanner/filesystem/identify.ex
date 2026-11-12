defmodule WatchClub.MediaSources.Import.Scanner.Filesystem.Identify do
  @moduledoc """
  Populates `candidate.identity` with what the file claims to be, from its
  path. Run by `Scanner.Filesystem` for each discovered candidate so that
  filesystem candidates arrive identified, like servarr ones.

  Dispatches on `media_source.media_type` and runs the `FilenameParser`
  (title/season/episode) and `ExternalIdExtractor` (`[tmdb-123]` etc.) over
  the path. `identity` is intentionally minimal — only the matching-relevant
  fields are projected onto the identity struct.
  """

  alias WatchClub.MediaSources.Filesystem
  alias WatchClub.MediaSources.Import.Candidate

  alias WatchClub.MediaSources.Import.Candidate.{
    EpisodeIdentity,
    MovieIdentity,
    SportsEventIdentity
  }

  alias WatchClub.MediaSources.Import.Scanner.Filesystem.Identify.ExternalIdExtractor
  alias WatchClub.MediaSources.Import.Scanner.Filesystem.Identify.FilenameParser

  @doc "Returns `candidate` with its `identity` populated from the path."
  def apply(%Candidate{} = candidate, media_source) do
    %{candidate | identity: extract_identity(media_source.media_type, candidate, media_source)}
  end

  defp extract_identity(:movie, candidate, _media_source) do
    {title, year} = FilenameParser.title_and_year(candidate.path)
    # A "Movie (Year)/file" folder names the year when the file name leaves it out
    {_folder_title, folder_year} = FilenameParser.title_and_year(Path.dirname(candidate.path))
    path_ids = ExternalIdExtractor.from_text(candidate.path)

    %MovieIdentity{
      title: title,
      year: year || folder_year,
      tmdb_id: path_ids.tmdb,
      imdb_id: path_ids.imdb
    }
  end

  defp extract_identity(:tv_show_episode, candidate, media_source) do
    episode = FilenameParser.parse_episode(candidate.path)

    %Filesystem{filesystem_path: root_path} = media_source.implementation

    title =
      episode[:tv_show_title] ||
        FilenameParser.clean_title(
          FilenameParser.tv_show_title_from_path(candidate.path, root_path)
        )

    path_ids = ExternalIdExtractor.from_text(Path.dirname(candidate.path))

    numbers =
      case episode do
        %{episode_number: first, ending_episode_number: last} -> Enum.to_list(first..last)
        _one_or_none -> [episode[:episode_number]]
      end

    %EpisodeIdentity{
      title: title,
      episodes:
        numbers
        |> Enum.zip(episode_titles(episode[:episode_title], numbers))
        |> Enum.map(fn {number, episode_title} ->
          %EpisodeIdentity.Episode{
            season_number: episode[:season_number],
            episode_number: number,
            title: episode_title
          }
        end),
      tmdb_id: path_ids.tmdb,
      tvdb_id: path_ids.tvdb,
      imdb_id: path_ids.imdb
    }
  end

  defp extract_identity(:sports_event, candidate, _media_source) do
    {title, year} = FilenameParser.title_and_year(candidate.path)
    {_folder_title, folder_year} = FilenameParser.title_and_year(Path.dirname(candidate.path))

    %SportsEventIdentity{
      title: title,
      year: year || folder_year,
      sportarr_id: ExternalIdExtractor.find_sportarr(candidate.path)
    }
  end

  defp extract_identity(:audiobook, _candidate, _media_source) do
    raise "Books not supported yet"
  end

  defp extract_identity(:ebook, _candidate, _media_source) do
    raise "Books not supported yet"
  end

  # Sonarr joins a file's episode titles with " + ", but names the halves of one story by their
  # shared title, "Fun Run" for "Fun Run (1)" and "Fun Run (2)": each half gets its part number back
  defp episode_titles(title, [_number]), do: [title]
  defp episode_titles(nil, numbers), do: Enum.map(numbers, fn _number -> nil end)

  defp episode_titles(title, numbers) do
    case String.split(title, " + ") do
      titles when length(titles) == length(numbers) -> titles
      _shared -> Enum.map(1..length(numbers), &"#{title} (#{&1})")
    end
  end
end
