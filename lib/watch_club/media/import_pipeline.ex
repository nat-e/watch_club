defmodule WatchClub.Media.ImportPipeline do
  @moduledoc """
  Turns each candidate file under an `ImportRun`'s configured location into a
  candidate with a terminal `Outcome`.

  Stages run per candidate, composed with `with/1`:

      Scan        → discover candidate files (one-shot, returns a stream)
      FilterExisting → continue, skip, or fail
      ExtractIdentity → describe what the file represents
      ExtractStructure → describe how the file is shaped (including sidecars for videos)
      ComputeOutcome → assign the terminal Outcome

  Stages return `{:ok, candidate}` to continue or `{:error, candidate}` to
  short-circuit (the candidate already carries its `Outcome`). `FilterExisting`
  may also return `:skip`, meaning the candidate produces no result row at all
  (spec: existing media without refresh is silently skipped). The pipeline
  emits one candidate with `:outcome` set per processed item; the caller
  (`ImportRun.Changes.ExecuteRun`) writes a result row per emitted candidate.
  """

  alias WatchClub.Media.ImportPipeline.{
    Candidate,
    ComputeOutcome,
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
        |> Task.async_stream(&process_candidate(&1, import_run, configuration),
          max_concurrency: @concurrency,
          ordered: false,
          timeout: :infinity
        )
        |> Stream.flat_map(fn
          {:ok, nil} -> []
          {:ok, candidate} -> [candidate]
        end)

      {:ok, stream}
    end
  rescue
    error in [Scan.Error] -> {:error, error.message}
  end

  defp process_candidate(%Candidate{} = candidate, import_run, configuration) do
    with {:ok, candidate} <- FilterExisting.apply(candidate, import_run),
         {:ok, candidate} <- ExtractIdentity.apply(candidate, configuration),
         {:ok, candidate} <- ExtractStructure.apply(candidate, configuration),
         {:ok, candidate} <- ComputeOutcome.apply(candidate, configuration) do
      candidate
    else
      :skip -> nil
      {:error, %Candidate{} = candidate_with_outcome} -> candidate_with_outcome
    end
  end
end
