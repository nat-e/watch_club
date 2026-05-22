defmodule WatchClub.Media.ImportRun.Changes.ExecuteRun do
  use Ash.Resource.Change

  alias WatchClub.Media, as: MediaDomain
  alias WatchClub.Media.ImportPipeline
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportRun

  @impl true
  def change(changeset, _opts, %{actor: actor}) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, %ImportRun{} = run} <- result,
           {:ok, loaded_run} <- Ash.load(run, :snapshot_configuration, actor: actor),
           {:ok, candidates} <- ImportPipeline.process_import(loaded_run),
           :ok <- record_outcomes(candidates, loaded_run, actor) do
        MediaDomain.complete_import_run(loaded_run, actor: actor)
      end
    end)
  end

  defp record_outcomes(candidates, run, actor) do
    Enum.each(candidates, &record_outcome(&1, run, actor))
    :ok
  end

  # Skipped candidates do not produce a result row (per CONTEXT.md: existing
  # Media re-encountered without refresh writes nothing).
  defp record_outcome(%Candidate{outcome: %{status: :skipped}}, _run, _actor), do: :ok

  defp record_outcome(%Candidate{outcome: outcome} = candidate, run, actor) do
    MediaDomain.create_import_result(
      %{
        media_import_id: run.id,
        status: outcome.status,
        path: candidate.path,
        message: outcome.message,
        metadata: result_metadata(candidate, run)
      },
      actor: actor
    )
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
