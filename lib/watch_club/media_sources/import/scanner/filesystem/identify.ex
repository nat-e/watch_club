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
  alias WatchClub.MediaSources.Import.Candidate.{EpisodeIdentity, MovieIdentity}
  alias WatchClub.MediaSources.Import.Scanner.Filesystem.Identify.ExternalIdExtractor
  alias WatchClub.MediaSources.Import.Scanner.Filesystem.Identify.FilenameParser

  require Logger

  @doc "Returns `candidate` with its `identity` populated from the path."
  def apply(%Candidate{} = candidate, media_source) do
    Logger.debug("Identifying #{candidate}")
    %{candidate | identity: extract_identity(media_source.media_type, candidate, media_source)}
  end

  defp extract_identity(:movie, candidate, _media_source) do
    {title, year} = FilenameParser.title_and_year(candidate.path)
    path_ids = ExternalIdExtractor.from_text(candidate.path)

    %MovieIdentity{
      title: title,
      year: year,
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

    %EpisodeIdentity{
      title: title,
      season_number: episode[:season_number],
      episode_number: episode[:episode_number],
      tmdb_id: path_ids.tmdb,
      tvdb_id: path_ids.tvdb,
      imdb_id: path_ids.imdb
    }
  end

  defp extract_identity(:audiobook, _candidate, _media_source) do
    raise "Books not supported yet"
  end

  defp extract_identity(:ebook, _candidate, _media_source) do
    raise "Books not supported yet"
  end
end
