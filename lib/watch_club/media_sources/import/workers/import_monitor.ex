defmodule WatchClub.MediaSources.Import.Workers.ImportMonitor do
  @moduledoc """
  Drives a `Import` from `:processing` to `:completed` once every
  other job tagged `media_import:<id>` (the `SourceScanner` and every
  `CandidateIngestor` candidate) has settled. Enqueued once when the Media
  Import is created (`Changes.Schedule`); snoozes itself until the rest
  of the work is done.

  Unique by `media_import_id` across active states so any second enqueue
  attempt collapses to the already-pending job.

  A Media Import with a discarded job fails, and counts the files whose ingest job was
  discarded as failed.

  Becomes a no-op if the Media Import has already reached a terminal
  state — `:cancel`, `:fail`, or a prior `:complete` got there first.
  """

  use Oban.Worker,
    queue: :media_import_monitors,
    max_attempts: 5,
    unique: [
      fields: [:worker, :args],
      keys: [:media_import_id],
      states: :incomplete,
      period: :infinity
    ]

  import Ecto.Query

  alias WatchClub.MediaSources.Import
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor
  alias WatchClub.{Repo, SystemActor}

  require Logger

  @active_states ~w(available scheduled executing retryable)
  @snooze_seconds 5

  @doc """
  Builds the Oban changeset for the monitor. Tagged so the cancel sweep
  catches it alongside the scan and candidate jobs.
  """
  def new_job(media_import_id) when is_binary(media_import_id) do
    new(
      %{media_import_id: media_import_id},
      tags: ["media_import:#{media_import_id}"]
    )
  end

  @impl Oban.Worker
  def perform(%Oban.Job{id: job_id, args: %{"media_import_id" => id}}) do
    actor = SystemActor.actor()

    case Ash.get(Import, id, actor: actor) do
      {:ok, %Import{status: :processing} = media_import} ->
        complete_if_done(media_import, job_id, actor)

      {:ok, _terminal} ->
        :ok

      {:error, %Ash.Error.Query.NotFound{}} ->
        :ok
    end
  end

  defp complete_if_done(%Import{id: id} = media_import, job_id, actor) do
    tag = "media_import:#{id}"

    jobs =
      from(j in Oban.Job,
        where: j.id != ^job_id,
        where: fragment("? @> ?", j.tags, ^[tag])
      )
      |> select([:state, :worker])
      |> Repo.all()

    cond do
      Enum.any?(jobs, &(&1.state in @active_states)) ->
        {:snooze, @snooze_seconds}

      Enum.any?(jobs, &(&1.state == "discarded")) ->
        Logger.info("Marking import #{media_import.id} failed",
          event: :mark_import_result,
          result: :failed,
          media_import_id: media_import.id
        )

        failed_file_count =
          Enum.count(jobs, &(&1.state == "discarded" and &1.worker == inspect(CandidateIngestor)))

        Ash.update!(media_import, %{failed_file_count: failed_file_count},
          action: :fail,
          actor: actor
        )

        :ok

      Enum.any?(jobs, &(&1.state == "cancelled")) ->
        Logger.info("Marking import #{media_import.id} cancelled",
          event: :mark_import_result,
          result: :cancelled,
          media_import_id: media_import.id
        )

        Ash.update!(media_import, %{}, action: :cancel, actor: actor)
        :ok

      true ->
        Logger.info("Marking import #{media_import.id} completed",
          event: :mark_import_result,
          result: :completed,
          media_import_id: media_import.id
        )

        Ash.update!(media_import, %{}, action: :complete, actor: actor)
        :ok
    end
  end
end
