defmodule WatchClub.Media.Workers.MonitorMediaImport do
  @moduledoc """
  Drives a `MediaImport` from `:processing` to `:completed` once every
  other job tagged `media_import:<id>` (the `ScanMediaSource` and every
  `ImportMediaFile` candidate) has settled. Enqueued once when the Media
  Import is created (`Changes.Schedule`); snoozes itself until the rest
  of the work is done.

  Unique by `media_import_id` across active states so any second enqueue
  attempt collapses to the already-pending job.

  Becomes a no-op if the Media Import has already reached a terminal
  state — `:cancel`, `:fail`, or a prior `:complete` got there first.
  """

  use Oban.Worker,
    queue: :monitor_media_imports,
    max_attempts: 5,
    unique: [
      fields: [:worker, :args],
      keys: [:media_import_id],
      states: [:available, :scheduled, :executing, :retryable],
      period: :infinity
    ]

  import Ecto.Query

  alias WatchClub.Media.MediaImport
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

    case Ash.get(MediaImport, id, actor: actor) do
      {:ok, %MediaImport{status: :processing} = media_import} ->
        complete_if_done(media_import, job_id, actor)

      {:ok, _terminal} ->
        :ok

      {:error, %Ash.Error.Query.NotFound{}} ->
        :ok
    end
  end

  defp complete_if_done(%MediaImport{id: id} = media_import, job_id, actor) do
    if work_pending?(id, job_id) do
      {:snooze, @snooze_seconds}
    else
      complete!(media_import, actor)
    end
  end

  defp work_pending?(media_import_id, own_job_id) do
    tag = "media_import:#{media_import_id}"

    from(j in Oban.Job,
      where: j.id != ^own_job_id,
      where: j.state in ^@active_states,
      where: fragment("? @> ?", j.tags, ^[tag])
    )
    |> Repo.exists?()
  end

  defp complete!(%MediaImport{} = media_import, actor) do
    case Ash.update(media_import, %{}, action: :complete, actor: actor) do
      {:ok, _} ->
        Logger.info("Completed MediaImport #{media_import.id}")
        :ok

      {:error, reason} = error ->
        Logger.error("Could not complete MediaImport #{media_import.id}: #{inspect(reason)}")

        error
    end
  end
end
