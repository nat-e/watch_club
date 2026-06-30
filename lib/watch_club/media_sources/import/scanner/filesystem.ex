defmodule WatchClub.MediaSources.Import.Scanner.Filesystem do
  @moduledoc """
  Filesystem implementation of `WatchClub.MediaSources.Import.Scanner`.

  `scan/1` walks the Media Source's configured filesystem location and
  returns a lazy stream of `Candidate`s — one per file under the root, each
  run through `Identify` so it carries its `identity` like servarr scanners
  do. Dedup against already-imported media is the `SourceScanner` worker's
  responsibility; this module emits unfiltered candidates.
  """
  @behaviour WatchClub.MediaSources.Import.Scanner

  alias WatchClub.MediaSources.Import
  alias WatchClub.MediaSources.Import.Scanner.Filesystem.{Identify, Scan}

  require Logger

  @impl true
  def scan(%Import{media_source: %_{} = media_source}) do
    Logger.info("Scan filesystem Media Source", event: :filesystem_scan_started)

    media_source
    |> Scan.stream_candidate_files!()
    |> Stream.map(&Identify.apply(&1, media_source))
  end
end
