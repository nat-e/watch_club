defmodule WatchClub.Media.MediaImport.Changes.Execute do
  @moduledoc """
  The work half of `MediaImport`'s `:run` action.

  The action transitions the Media Import to `:processing` inside the
  database transaction (via `transition_state(:processing)` declared in the
  action's `changes` block) and then registers this change as an
  `after_transaction` callback. Once the transaction commits we:

    1. Load the live `media_source` (with its `:implementation`).
    2. Dispatch to the pipeline matching the Media Source's type.
    3. Set the Media Import as completed.

  If anything fails or raises, the error propagates to AshOban, which runs
  the trigger's `on_error: :fail` action to mark the Media Import failed.
  """

  use Ash.Resource.Change

  alias WatchClub.Media.{FilesystemImportPipeline, MediaImport}

  @filesystem_pipeline Application.compile_env(
                         :watch_club,
                         :import_pipeline_filesystem,
                         FilesystemImportPipeline
                       )

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, %MediaImport{} = media_import} <- result,
           {:ok, loaded} <-
             Ash.load(media_import, [media_source: [:implementation]], scope: context),
           :ok <- import_pipeline(loaded.media_source.source_type).import_medias(loaded) do
        Ash.update(loaded, %{}, action: :complete, scope: context)
      else
        {:error, _} = error -> error
        other -> {:error, "Unexpected pipeline result: #{inspect(other)}"}
      end
    end)
  end

  defp import_pipeline(:filesystem), do: @filesystem_pipeline
end
