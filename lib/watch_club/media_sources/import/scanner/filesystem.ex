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

  alias WatchClub.MediaSources.Import.Scanner.Filesystem.{Identify, Scan}
  alias WatchClub.MediaSources.Import

  @impl true
  def scan(%Import{media_source: %_{} = media_source}) do
    with {:ok, candidates} <- Scan.stream_candidate_files(media_source) do
      {:ok, Stream.map(candidates, &Identify.apply(&1, media_source))}
    end
  end
end
