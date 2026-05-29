defmodule WatchClub.Media.Workers.ImportMediaFile do
  @moduledoc """
  Runs the per-candidate stages of an import pipeline for a single file.
  One Oban job per discovered file; enqueued in chunks by
  `WatchClub.Media.Workers.ScanMediaSource` during the scan phase.

  Returns `:ok` for both successful imports and explicit `{:halt, _}`
  short-circuits — halts are a clean per-file skip (unsupported file,
  missing metadata, etc.) and should not consume retry attempts. Stage
  errors return `{:error, _}` so Oban retries with exponential backoff.

  Unique by `(media_import_id, path)` across active states so re-running
  the scan (manual retry, recovery) does not double-enqueue candidates.
  Tagged `media_import:<id>` so the cancel path and finalizer can find
  every candidate belonging to a Media Import.
  """

  use Oban.Worker,
    queue: :import_media_files,
    max_attempts: 3,
    unique: [
      fields: [:worker, :args],
      keys: [:media_import_id, :path],
      states: [:available, :scheduled, :executing, :retryable],
      period: :infinity
    ]

  alias WatchClub.Media.ImportPipeline
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.MediaImport
  alias WatchClub.SystemActor

  require Logger

  @doc """
  Builds the Oban changeset for one candidate file under the given
  Media Import.
  """
  def new_job(%MediaImport{id: id}, path) when is_binary(path) do
    new(
      %{media_import_id: id, path: path},
      tags: ["media_import:#{id}"]
    )
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_import_id" => id, "path" => path}}) do
    case Ash.get(MediaImport, id,
           load: [media_source: [:implementation]],
           actor: SystemActor.actor()
         ) do
      {:ok, media_import} ->
        process(Candidate.new(path), media_import)

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:cancel, "MediaImport #{id} not found"}
    end
  end

  defp process(%Candidate{} = candidate, %MediaImport{} = media_import) do
    pipeline = ImportPipeline.for_source_type(media_import.media_source.source_type)

    case pipeline.process_candidate(candidate, media_import) do
      :ok ->
        :ok

      {:halt, reason} ->
        Logger.warning("Stop processing candidate #{candidate}: #{inspect(reason)}")
        :ok

      {:error, _} = error ->
        error
    end
  end
end
