defmodule WatchClub.MediaSources.Import.Scanner do
  @moduledoc """
  Behaviour + registry for the source-specific scan phase of an import.

  A scanner knows how to enumerate one Media Source type into `Candidate`s,
  each already carrying its `path` and `identity`. The `SourceScanner` worker
  picks the scanner for the Media Source's `source_type` via `for_source_type/1`,
  calls `scan/1`, and fans out one `CandidateIngestor` job per candidate.

  Test overrides go through `:watch_club, :import_scanner_filesystem` /
  `:import_scanner_radarr` / `:import_scanner_sonarr`.
  """

  alias WatchClub.MediaSources.Import
  alias WatchClub.MediaSources.Import.Candidate

  @filesystem_scanner Application.compile_env(
                        :watch_club,
                        :import_scanner_filesystem,
                        WatchClub.MediaSources.Import.Scanner.Filesystem
                      )

  @radarr_scanner Application.compile_env(
                    :watch_club,
                    :import_scanner_radarr,
                    WatchClub.MediaSources.Import.Scanner.Radarr
                  )

  @sonarr_scanner Application.compile_env(
                    :watch_club,
                    :import_scanner_sonarr,
                    WatchClub.MediaSources.Import.Scanner.Sonarr
                  )

  @callback scan(Import.t()) :: Enumerable.t(Candidate.t())

  @doc "Returns the scanner module for a given Media Source type."
  def for_source_type(:filesystem), do: @filesystem_scanner
  def for_source_type(:radarr), do: @radarr_scanner
  def for_source_type(:sonarr), do: @sonarr_scanner
end
