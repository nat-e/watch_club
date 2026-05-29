defmodule WatchClub.Media.FilesystemImportPipeline do
  @moduledoc """
  Filesystem implementation of `WatchClub.Media.ImportPipeline`.

  `scan/1` walks the Media Source's configured filesystem location and
  returns a stream of every candidate file under the root. Dedup against
  already-imported media is the worker's responsibility — this module
  emits unfiltered candidates.

  `process_candidate/2` runs the per-file stages for a single candidate:
  `ExtractIdentity → ExtractStructure → MatchContent → SaveMedia`. The
  caller (an `ImportMediaFile` Oban job) decides what to do with `:ok`,
  `{:halt, reason}` or `{:error, reason}`.
  """
  @behaviour WatchClub.Media.ImportPipeline

  alias WatchClub.Media.ImportPipeline.{
    Candidate,
    ExtractIdentity,
    ExtractStructure,
    MatchContent,
    SaveMedia,
    Scan
  }

  alias WatchClub.Media.MediaImport

  require Logger

  @impl true
  def scan(%MediaImport{media_source: %_{} = media_source}) do
    Scan.stream_candidate_files(media_source)
  end

  @impl true
  def process_candidate(%Candidate{} = candidate, %MediaImport{} = media_import) do
    Logger.info("Processing import candidate: #{candidate}")

    with {:ok, candidate} <- ExtractIdentity.apply(candidate, media_import),
         {:ok, candidate} <- ExtractStructure.apply(candidate, media_import),
         {:ok, candidate} <- MatchContent.apply(candidate, media_import),
         {:ok, candidate} <- SaveMedia.apply(candidate, media_import) do
      Logger.info("Finished processing candidate: #{candidate}")
      :ok
    end
  end
end
