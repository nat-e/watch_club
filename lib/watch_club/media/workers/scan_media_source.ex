defmodule WatchClub.Media.Workers.ScanMediaSource do
  @moduledoc """
  Drives the scan phase of a `MediaImport`. Loads the Media Source, picks
  the pipeline matching its `source_type`, calls `scan/1` and enqueues one
  `ImportMediaFile` Oban job per candidate — chunked so workers start
  picking up early files before the whole tree has been walked.

  Owns the dedup-vs-already-imported-media decision: before enqueueing,
  loads every existing `Media` path under the source's root and filters
  matching candidates out of the stream. When the Media Import has
  `refresh_metadata? = true` the skip set is empty so every candidate is
  re-processed.

  The `MonitorMediaImport` monitor (enqueued at Media Import creation by
  `Changes.Schedule`) is what drives the Media Import to its terminal
  state once this scan and all candidates have finished. On failure this
  worker transitions the Media Import to `:failed` directly so the caller
  and UI observe the outcome without waiting on the monitor.

  Tagged `media_import:<id>` so the cancel path can sweep this job
  alongside the candidate and monitor jobs in one
  `Oban.cancel_all_jobs/1` call.
  """

  use Oban.Worker, queue: :scan_media_sources, max_attempts: 1

  alias WatchClub.Media, as: MediaDomain

  alias WatchClub.Media.{
    FilesystemMediaSource,
    ImportPipeline,
    MediaImport,
    MediaSource,
    RadarrMediaSource
  }

  alias WatchClub.Media.Workers.ImportMediaFile
  alias WatchClub.SystemActor

  require Logger

  @chunk_size 1_000

  @doc """
  Builds the Oban changeset for a `MediaImport`. Callers go through this
  helper so the args contract and tag scheme stay in one place.
  """
  def new_job(%MediaImport{id: id}) do
    new(
      %{media_import_id: id},
      tags: ["media_import:#{id}"]
    )
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_import_id" => id}}) do
    case Ash.get(MediaImport, id,
           load: [media_source: [:implementation]],
           actor: SystemActor.actor()
         ) do
      {:ok, media_import} ->
        scan_and_enqueue(media_import)

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:cancel, "MediaImport #{id} not found"}
    end
  end

  defp scan_and_enqueue(%MediaImport{} = media_import) do
    pipeline = ImportPipeline.for_source_type(media_import.media_source.source_type)

    try do
      with {:ok, skip_paths} <- load_skip_paths(media_import),
           {:ok, candidates} <- pipeline.scan(media_import) do
        count =
          candidates
          |> Stream.reject(&MapSet.member?(skip_paths, &1.path))
          |> enqueue_candidates(media_import)

        Logger.info("Enqueued #{count} candidate(s) for MediaImport #{media_import.id}")
        :ok
      else
        {:error, reason} = error ->
          Logger.error("Scan failed for MediaImport #{media_import.id}: #{inspect(reason)}")
          mark_failed(media_import)
          error
      end
    rescue
      exception ->
        Logger.error(
          "Scan crashed for MediaImport #{media_import.id}: " <>
            Exception.format(:error, exception, __STACKTRACE__)
        )

        mark_failed(media_import)
        reraise exception, __STACKTRACE__
    end
  end

  defp load_skip_paths(%MediaImport{refresh_metadata?: true}), do: {:ok, MapSet.new()}

  defp load_skip_paths(%MediaImport{
         media_source: %MediaSource{
           implementation: %FilesystemMediaSource{filesystem_path: root_path}
         }
       }) do
    skip_paths_under(root_path)
  end

  defp load_skip_paths(%MediaImport{
         media_source: %MediaSource{
           implementation: %RadarrMediaSource{
             root_folder_path: root_folder_path,
             local_root_folder_path: local_root_folder_path
           }
         }
       }) do
    # Candidate paths are mapped onto WatchClub's disk; dedup against the local root.
    skip_paths_under(local_root_folder_path || root_folder_path)
  end

  defp skip_paths_under(root_path) do
    Logger.info("Load existing medias for #{root_path}")

    with {:ok, media} <-
           MediaDomain.list_media_under_path_prefix(root_path, actor: SystemActor.actor()) do
      Logger.info("Found #{length(media)} existing medias in #{root_path}")
      {:ok, MapSet.new(media, & &1.path)}
    end
  end

  defp enqueue_candidates(candidates, %MediaImport{} = media_import) do
    candidates
    |> Stream.chunk_every(@chunk_size)
    |> Enum.reduce(0, fn chunk, acc ->
      chunk
      |> Enum.map(&ImportMediaFile.new_job(media_import, &1))
      |> Oban.insert_all()

      acc + length(chunk)
    end)
  end

  defp mark_failed(%MediaImport{} = media_import) do
    case Ash.update(media_import, %{}, action: :fail, actor: SystemActor.actor()) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "Could not mark MediaImport #{media_import.id} as :failed: #{inspect(reason)}"
        )
    end
  end
end
