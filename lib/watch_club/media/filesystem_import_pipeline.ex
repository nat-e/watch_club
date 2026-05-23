defmodule WatchClub.Media.FilesystemImportPipeline do
  @moduledoc """
  Runs each candidate file under an `ImportRun`'s configured location through
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

  alias WatchClub.Media.{ImportRun, Media}
  alias WatchClub.SystemActor

  require Logger

  @concurrency 2
  @candidate_timeout_ms :timer.seconds(30)

  @impl true
  def import_medias(%ImportRun{snapshot_configuration: %_{} = configuration} = import_run) do
    with {:ok, candidates} <- Scan.list_candidate_files(configuration),
         {:ok, candidates} <-
           filter_existing(
             candidates,
             configuration.filesystem_path,
             import_run.refresh_metadata?
           ) do
      candidates
      |> Task.async_stream(&process_candidate(&1, import_run),
        max_concurrency: @concurrency,
        ordered: false,
        timeout: @candidate_timeout_ms,
        on_timeout: :kill_task,
        zip_input_on_exit: true
      )
      |> Stream.run()
    end
  end

  # When not refreshing metadata, filter candidates that already exist.
  defp filter_existing(candidates, _root_path, true), do: {:ok, candidates}

  defp filter_existing(candidates, root_path, _refresh_metadata?) do
    with {:ok, media} <-
           MediaDomain.list_media_under_path_prefix(root_path, actor: SystemActor.actor()) do
      by_path = Map.new(media, fn %Media{path: path} = m -> {path, m} end)

      {:ok,
       candidates |> Enum.reject(fn candidate -> Map.get(by_path, candidate.path) != nil end)}
    end
  end

  defp process_candidate(%Candidate{} = candidate, %ImportRun{} = import_run) do
    with {:ok, candidate} <- ExtractIdentity.apply(candidate, import_run),
         {:ok, candidate} <- ExtractStructure.apply(candidate, import_run),
         {:ok, candidate} <- MatchContent.apply(candidate, import_run),
         {:ok, candidate} <- SaveMedia.apply(candidate, import_run) do
      Logger.info("Finished processing candidate: #{candidate.path}")
      :ok
    else
      {:halt, reason} ->
        Logger.info("Stop processing candidate: #{candidate.path}: #{inspect(reason)}")
        :ok
    end
  end
end
