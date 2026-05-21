defmodule WatchClub.Media.ImportRun.Changes.ExecuteRun do
  use Ash.Resource.Change

  alias WatchClub.Media, as: MediaDomain
  alias WatchClub.Media.ImportPipeline
  alias WatchClub.Media.ImportRun

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_transaction(changeset, after_transaction(context.actor))
  end

  defp after_transaction(actor) do
    fn changeset, result ->
      case result do
        {:ok, %ImportRun{} = run} ->
          run_pipeline_and_complete(run, actor)

        {:error, error} ->
          changeset.data
          |> fail(actor)
          |> case do
            {:ok, _run} -> {:error, error}
            {:error, fail_error} -> {:error, fail_error}
          end
      end
    end
  end

  defp run_pipeline_and_complete(run, actor) do
    try do
      with {:ok, loaded_run} <- Ash.load(run, :snapshot_configuration, actor: actor),
           :ok <- ImportPipeline.process_import(loaded_run),
           {:ok, completed_run} <- complete(loaded_run, actor) do
        {:ok, completed_run}
      else
        {:error, error} -> fail_after_error(run, actor, error)
      end
    rescue
      error -> fail_after_error(run, actor, error)
    end
  end

  defp fail_after_error(run, actor, error) do
    run
    |> fail(actor)
    |> case do
      {:ok, _run} -> {:error, error}
      {:error, fail_error} -> {:error, fail_error}
    end
  end

  defp complete(run, actor) do
    MediaDomain.complete_import_run(run, actor: actor)
  end

  defp fail(run, actor) do
    MediaDomain.fail_import_run(run, actor: actor)
  end
end
