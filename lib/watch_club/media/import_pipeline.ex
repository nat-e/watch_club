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
  """

  alias WatchClub.Media.ImportPipeline.{
    Candidate,
    ExtractIdentity,
    ExtractStructure,
    FilterExisting,
    Scan
  }

  alias WatchClub.Media.ImportRun

  @concurrency 2

  def process_import(%ImportRun{snapshot_configuration: %_{} = configuration} = import_run) do
    with {:ok, candidates} <- Scan.stream(configuration) do
      stream =
        candidates
        |> Task.async_stream(&process_candidate(&1, import_run),
          max_concurrency: @concurrency,
          ordered: false,
          timeout: :infinity
        )
        |> Stream.map(fn {:ok, %Candidate{} = candidate} -> candidate end)

      {:ok, stream}
    end
  rescue
    error in [Scan.Error] -> {:error, error.message}
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
