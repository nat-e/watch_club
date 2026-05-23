defmodule WatchClub.Media.ImportRun.Changes.ExecuteRun do
  @moduledoc """
  The work half of `ImportRun`'s `:run` action.

  The action transitions the run to `:processing` inside the database
  transaction (via `transition_state(:processing)` declared in the action's
  `changes` block) and then registers this change as an `after_transaction`
  callback. Once the transaction commits we:

    1. Load `:snapshot_configuration`.
    2. Run the import pipeline.
    3. Set the run as completed

  If anything fails or raises, the error propagates to AshOban, which runs
  the trigger's `on_error: :fail` action to mark the run failed.
  """

  use Ash.Resource.Change

  alias WatchClub.Media.{FilesystemImportPipeline, ImportRun}

  @filesystem_pipeline Application.compile_env(
                         :watch_club,
                         :import_pipeline_filesystem,
                         FilesystemImportPipeline
                       )

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, %ImportRun{} = run} <- result,
           {:ok, loaded_run} <- Ash.load(run, :snapshot_configuration, scope: context),
           :ok <-
             import_pipeline(loaded_run.snapshot_configuration.source_type).import_medias(
               loaded_run
             ) do
        Ash.update(loaded_run, %{}, action: :complete, scope: context)
      else
        {:error, _} = error -> error
        other -> {:error, "Unexpected pipeline result: #{inspect(other)}"}
      end
    end)
  end

  defp import_pipeline(:filesystem), do: @filesystem_pipeline
end
