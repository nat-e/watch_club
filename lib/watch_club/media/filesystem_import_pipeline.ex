defmodule WatchClub.Media.FilesystemImportPipeline do
  @moduledoc """
  Runs each candidate file under a `MediaImport`'s configured location through
  the per-candidate stages, composed with `with/1`:

      ExtractIdentity   → describe what the file represents
      ExtractStructure  → describe how the file is shaped (sidecars included for videos)
      MatchContent      → resolve identity to a Content row
      SaveMedia         → persist Media (and tracks for videos)

  Stages return `{:ok, candidate}` to continue or `{:halt, reason}` to
  short-circuit.

  Before per-candidate processing the pipeline loads every existing `Media`
  under the configured filesystem path in one query and (when not refreshing
  metadata) drops candidates whose path is already imported.
  """
  @behaviour WatchClub.Media.ImportPipeline

  alias WatchClub.Media, as: MediaDomain

  alias WatchClub.Media.ImportPipeline.{
    Candidate,
    ExtractIdentity,
    ExtractStructure,
    MatchContent,
    SaveMedia,
    Scan
  }

  alias WatchClub.Media.MediaImport
  alias WatchClub.SystemActor

  require Logger

  @concurrency 2
  @candidate_timeout_ms :timer.seconds(30)

  @impl true
  def import_medias(%MediaImport{source_snapshot: %_{} = media_source} = media_import) do
    with {:ok, skip_paths} <-
           load_existing_media(media_source.filesystem_path, media_import.refresh_metadata?),
         {:ok, candidate_stream} <- Scan.stream_candidate_files(media_source, skip_paths) do
      candidate_stream
      |> Task.async_stream(&process_candidate(&1, media_import),
        max_concurrency: @concurrency,
        ordered: false,
        timeout: @candidate_timeout_ms,
        on_timeout: :kill_task,
        zip_input_on_exit: true
      )
      |> Stream.run()
    end
  end

  # Returns the set of media paths already imported under `root_path`, used by
  # `Scan` to skip them without statting. When refreshing metadata the caller
  # wants to re-process everything, so the set is empty.
  defp load_existing_media(_root_path, true), do: {:ok, MapSet.new()}

  defp load_existing_media(root_path, _refresh_metadata?) do
    Logger.info("Load existing medias for #{root_path}")

    with {:ok, media} <-
           MediaDomain.list_media_under_path_prefix(root_path, actor: SystemActor.actor()) do
      Logger.info("Found #{length(media)} existing medias in #{root_path}")
      {:ok, MapSet.new(media, & &1.path)}
    end
  end

  defp process_candidate(%Candidate{} = candidate, %MediaImport{} = media_import) do
    Logger.info("Processing import candidate: #{candidate}")

    with {:ok, candidate} <- ExtractIdentity.apply(candidate, media_import),
         {:ok, candidate} <- ExtractStructure.apply(candidate, media_import),
         {:ok, candidate} <- MatchContent.apply(candidate, media_import),
         {:ok, candidate} <- SaveMedia.apply(candidate, media_import) do
      Logger.info("Finished processing candidate: #{candidate}")
      :ok
    else
      {:halt, reason} ->
        Logger.warning("Stop processing candidate: #{candidate}: #{inspect(reason)}")
        :ok
    end
  end
end
