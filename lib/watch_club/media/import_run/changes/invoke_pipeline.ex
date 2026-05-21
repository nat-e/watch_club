defmodule WatchClub.Media.ImportRun.Changes.InvokePipeline do
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
        {:ok, %ImportRun{} = import_run} ->
          process_and_mark_completed(import_run, actor)

        {:error, error} ->
          changeset.data
          |> mark_failed(actor)
          |> case do
            {:ok, _import_run} -> {:error, error}
            {:error, mark_failed_error} -> {:error, mark_failed_error}
          end
      end
    end
  end

  defp process_and_mark_completed(import_run, actor) do
    try do
      with :ok <- ImportPipeline.process_import(import_run),
           {:ok, completed_import_run} <- mark_completed(import_run, actor) do
        {:ok, completed_import_run}
      else
        {:error, error} -> mark_failed_after_error(import_run, actor, error)
      end
    rescue
      error -> mark_failed_after_error(import_run, actor, error)
    end
  end

  defp mark_failed_after_error(import_run, actor, error) do
    import_run
    |> mark_failed(actor)
    |> case do
      {:ok, _import_run} -> {:error, error}
      {:error, mark_failed_error} -> {:error, mark_failed_error}
    end
  end

  defp mark_completed(import_run, actor) do
    MediaDomain.mark_import_run_completed(import_run, actor: actor)
  end

  defp mark_failed(import_run, actor) do
    MediaDomain.mark_import_run_failed(import_run, actor: actor)
  end
end
