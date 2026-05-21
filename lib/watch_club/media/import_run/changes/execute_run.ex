defmodule WatchClub.Media.ImportRun.Changes.ExecuteRun do
  use Ash.Resource.Change

  alias WatchClub.Media, as: MediaDomain
  alias WatchClub.Media.ImportPipeline
  alias WatchClub.Media.ImportPipeline.Candidate
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
           {:ok, candidates} <- ImportPipeline.process_import(loaded_run),
           :ok <- record_outcomes(candidates, loaded_run, actor),
           {:ok, completed_run} <- complete(loaded_run, actor) do
        {:ok, completed_run}
      else
        {:error, error} -> fail_after_error(run, actor, error)
      end
    rescue
      error -> fail_after_error(run, actor, error)
    end
  end

  defp record_outcomes(candidates, run, actor) do
    candidates
    |> Enum.each(&record_outcome(&1, run, actor))

    :ok
  end

  defp record_outcome(%Candidate{outcome: outcome} = candidate, run, actor) do
    MediaDomain.create_import_result(
      %{
        media_import_id: run.id,
        status: outcome.status,
        path: candidate.path,
        message: outcome.message,
        metadata: result_metadata(candidate, run, outcome)
      },
      actor: actor
    )
  end

  defp result_metadata(%Candidate{} = candidate, %ImportRun{} = run, outcome) do
    configuration = run.snapshot_configuration

    outcome.metadata
    |> stringify_keys()
    |> Map.merge(%{
      "content_type" => Atom.to_string(configuration.content_type),
      "media_type" => Atom.to_string(configuration.media_type),
      "relative_path" => candidate.relative_path,
      "existing_media_id" => existing_media_id(candidate)
    })
  end

  defp existing_media_id(%Candidate{existing_media: %{id: id}}), do: id
  defp existing_media_id(%Candidate{}), do: nil

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
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
