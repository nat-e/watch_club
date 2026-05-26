defmodule WatchClub.Media.ImportPipeline.ExtractIdentity do
  @moduledoc """
  Populates `candidate.identity` with what the file claims to be.

  Orchestration only. Dispatches on `configuration.content_type`, runs the
  `FilenameParser` (what the path claims) and the matching `NfoParser` entry
  point (what the sidecar XML claims), then merges the two into the
  `Candidate.Identity` struct.

  Merge policy, mirroring Jellyfin's provider precedence (NFOs are authored
  intent, filenames are heuristics):

    * Scalar fields: the NFO value overwrites the filename value when present.
    * `external_ids`: unioned slot-by-slot (filename `[tmdb-123]` + NFO
      `<imdbid>tt456</imdbid>` both land).

  `Identity` is intentionally minimal — NFO parsers extract a richer set of
  metadata into their own result structs, but only the matching-relevant
  subset is projected onto `Identity` here.
  """

  @behaviour WatchClub.Media.ImportPipeline.Stage

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.{EpisodeIdentity, MovieIdentity}
  alias WatchClub.Media.ImportPipeline.ExtractIdentity.ExternalIdExtractor
  alias WatchClub.Media.ImportPipeline.ExtractIdentity.FilenameParser
  alias WatchClub.Media.ImportRun

  require Logger

  @impl true
  def apply(%Candidate{} = candidate, %ImportRun{snapshot_configuration: configuration}) do
    Logger.debug("Extracting identity for #{candidate}")
    identity = extract_identity(configuration.media_type, candidate, configuration)
    {:ok, %{candidate | identity: identity}}
  end

  defp extract_identity(:movie, candidate, _configuration) do
    {title, year} = FilenameParser.title_and_year(candidate.path)
    path_ids = ExternalIdExtractor.from_text(candidate.path)

    %MovieIdentity{
      title: title,
      year: year,
      tmdb_id: path_ids.tmdb,
      imdb_id: path_ids.imdb
    }
  end

  defp extract_identity(:tv_show_episode, candidate, configuration) do
    episode = FilenameParser.parse_episode(candidate.path)

    title =
      episode[:tv_show_title] ||
        FilenameParser.clean_title(
          FilenameParser.tv_show_title_from_path(candidate.path, configuration.filesystem_path)
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

  defp extract_identity(:audiobook, _candidate, _configuration) do
    raise "Books not supported yet"
  end

  defp extract_identity(:ebook, _candidate, _configuration) do
    raise "Books not supported yet"
  end
end
