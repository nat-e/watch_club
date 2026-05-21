defmodule WatchClub.Media.ImportPipeline do
  @moduledoc """
  Turns each candidate file under an `ImportRun`'s configured location into a
  candidate with a terminal `Outcome`.

  Stages implement the `Stage` behaviour and run per candidate, composed with
  `with/1`:

      FilterExisting    → continue, skip, or fail
      ExtractIdentity   → describe what the file represents
      ExtractStructure  → describe how the file is shaped (sidecars included for videos)

  Stages return `{:ok, candidate}` to continue or `{:halt, candidate, reason, message}`
  to short-circuit. On success the pipeline finalizes via `Candidate.set_outcome/1`;
  on halt it finalizes via `Candidate.set_halted_outcome/3`. Stages do not construct
  outcomes themselves.

  The pipeline emits one candidate per processed item, always with `:outcome`
  set. The caller (`ImportRun.Changes.ExecuteRun`) decides what to persist —
  notably, `:skipped` outcomes do not produce a result row.

  Before per-candidate processing starts the pipeline loads every existing
  `Media` under the configured filesystem path in one query, then tags each
  candidate with its `existing_media` (if any) for `FilterExisting` to act on.
  """

  alias WatchClub.Media, as: MediaDomain

  alias WatchClub.Media.ImportPipeline.{
    Candidate,
    ExtractIdentity,
    ExtractStructure,
    FilterExisting,
    Scan
  }

  alias WatchClub.Media.{ImportRun, Media}
  alias WatchClub.SystemActor

  @concurrency 2
  @candidate_timeout_ms :timer.seconds(30)

  def process_import(%ImportRun{snapshot_configuration: %_{} = configuration} = import_run) do
    with {:ok, candidates} <- Scan.stream(configuration),
         {:ok, candidates} <- load_existing_media(candidates, configuration) do
      stream =
        candidates
        |> Task.async_stream(&process_candidate(&1, import_run),
          max_concurrency: @concurrency,
          ordered: false,
          timeout: @candidate_timeout_ms,
          on_timeout: :kill_task,
          zip_input_on_exit: true
        )
        |> Stream.map(fn
          {:ok, %Candidate{} = candidate} ->
            candidate

          {:exit, {%Candidate{} = candidate, :timeout}} ->
            Candidate.set_halted_outcome(
              candidate,
              :failed,
              "Processing exceeded #{@candidate_timeout_ms}ms"
            )
        end)

      {:ok, stream}
    end
  rescue
    error in [Scan.Error] -> {:error, error.message}
  end

  defp load_existing_media(candidates, configuration) do
    with {:ok, media} <-
           MediaDomain.list_media_under_path_prefix(configuration.filesystem_path,
             actor: SystemActor.actor()
           ) do
      by_path = Map.new(media, fn %Media{path: path} = m -> {path, m} end)

      tagged =
        Stream.map(candidates, fn %Candidate{path: path} = candidate ->
          case Map.get(by_path, path) do
            %Media{id: id, type: type} -> %{candidate | existing_media: %{id: id, type: type}}
            nil -> candidate
          end
        end)

      {:ok, tagged}
    end
  end

  defp process_candidate(%Candidate{} = candidate, %ImportRun{} = import_run) do
    with {:ok, candidate} <- FilterExisting.apply(candidate, import_run),
         {:ok, candidate} <- ExtractIdentity.apply(candidate, import_run),
         {:ok, candidate} <- ExtractStructure.apply(candidate, import_run) do
      Candidate.set_outcome(candidate)
    else
      {:halt, candidate, reason, message} ->
        Candidate.set_halted_outcome(candidate, reason, message)
    end
  end
end
