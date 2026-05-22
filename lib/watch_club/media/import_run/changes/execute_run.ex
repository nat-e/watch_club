defmodule WatchClub.Media.ImportRun.Changes.ExecuteRun do
  @moduledoc """
  The work half of `ImportRun`'s `:run` action.

  The action transitions the run to `:processing` inside the database
  transaction (via `transition_state(:processing)` declared in the action's
  `changes` block) and then registers this change as an `after_transaction`
  callback. Once the transaction commits we:

    1. Load `:snapshot_configuration`.
    2. Run the import pipeline.
    3. Hand the per-candidate outcomes to the `:complete` action, which
       writes the `ImportResult` rows and transitions the run to
       `:completed` atomically in a single transaction.

  If anything fails or raises, the error propagates to AshOban, which runs
  the trigger's `on_error: :fail` action to mark the run failed.
  """

  use Ash.Resource.Change

  alias WatchClub.Media.ImportPipeline
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportRun

  @impl true
  def change(changeset, _opts, %{actor: actor}) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, %ImportRun{} = run} <- result,
           {:ok, loaded_run} <- Ash.load(run, :snapshot_configuration, actor: actor),
           {:ok, candidates} <- ImportPipeline.process_import(loaded_run) do
        Ash.update(loaded_run, %{results: result_inputs(candidates, loaded_run)},
          action: :complete,
          actor: actor
        )
      end
    end)
  end

  # Skipped candidates do not produce a result row (per CONTEXT.md: existing
  # Media re-encountered without refresh writes nothing).
  defp result_inputs(candidates, run) do
    candidates
    |> Stream.reject(fn %Candidate{outcome: %{status: status}} -> status == :skipped end)
    |> Enum.map(&result_input(&1, run))
  end

  defp result_input(%Candidate{outcome: outcome} = candidate, run) do
    %{
      status: outcome.status,
      path: candidate.path,
      message: outcome.message,
      metadata: result_metadata(candidate, run)
    }
  end

  defp result_metadata(%Candidate{} = candidate, %ImportRun{} = run) do
    configuration = run.snapshot_configuration

    %{
      "content_type" => Atom.to_string(configuration.content_type),
      "media_type" => Atom.to_string(configuration.media_type),
      "relative_path" => candidate.relative_path,
      "existing_media_id" => existing_media_id(candidate)
    }
  end

  defp existing_media_id(%Candidate{existing_media: %{id: id}}), do: id
  defp existing_media_id(%Candidate{}), do: nil
end
