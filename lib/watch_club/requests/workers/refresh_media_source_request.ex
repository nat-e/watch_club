defmodule WatchClub.Requests.Workers.RefreshMediaSourceRequest do
  @moduledoc """
  Asks the source's app for the status of a Media Source Request, see
  `WatchClub.MediaSources.Servarr.App.request_state!/2`.

  This will recompute the status and progress of the MSR, and update it.

  This also takes care of re-scheduling itself until it's in a completed state (:downloaded):
  - If the request is considered active and we can expect frequent changes (it is recently submitted or downloading),
    re-schedule in 10 seconds. This is particularly useful for refreshing the progress.
  - If the request is considered blocked (needs human attention, has not been found or is not released), we refresh it
    every hour.

  Because of that, we don't need to rely on Grab/Download webhooks from Radarr/Sonarr, since they can't give us download
  progress anyway.
  """
  use Oban.Worker,
    queue: :media_source_requests,
    unique: [
      keys: [:media_source_request_id],
      states: :incomplete,
      period: :infinity
    ]

  alias WatchClub.MediaSources.Servarr.Flavor
  alias WatchClub.Requests.MediaSourceRequest
  alias WatchClub.SystemActor

  require Ash.Query
  require Logger

  def new_job(media_source_request_id, opts \\ []) do
    new(%{media_source_request_id: media_source_request_id}, opts)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_source_request_id" => id}}) do
    Logger.metadata(media_source_request_id: id)
    actor = SystemActor.actor()

    %MediaSourceRequest{} =
      request =
      MediaSourceRequest
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.load(media_source: [:implementation])
      |> Ash.read_one!(actor: actor)

    servarr = request.media_source.implementation

    {status, progress} =
      Flavor.app(servarr.flavor).request_state!(servarr, request.external_resource_id)

    status_changed? = status != request.status
    progress_changed? = round(progress) != round(request.download_progress)

    if status_changed? or progress_changed? do
      request |> Ash.update!(%{status: status, download_progress: progress}, actor: actor)
    end

    if status_changed?,
      do:
        Logger.info("Status updated to #{status} for #{request.id}",
          event: :msr_status_changed,
          status: status
        )

    if progress_changed?,
      do:
        Logger.info("Progress updated to #{progress} for #{request.id}",
          event: :msr_progress_changed,
          progress: progress
        )

    five_minutes_ago = DateTime.utc_now() |> DateTime.add(-5, :minute)

    not_found? =
      status == :searching and
        request.inserted_at |> DateTime.before?(five_minutes_ago)

    Logger.info("Status: #{status} - Progress: #{progress}")

    cond do
      # If the request is "blocked", re-schedule a refresh in 1 hour
      not_found? or status in [:not_released, :needs_attention] ->
        {:snooze, {1, :hour}}

      # If the request is "active", re-schedule a refresh in 5 seconds
      status in [:searching, :downloading] ->
        {:snooze, 10}

      # Downloaded — stop refreshing.
      true ->
        :ok
    end
  end
end
