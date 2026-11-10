defmodule WatchClub.Requests.Workers.RefreshMediaSourceRequest do
  @moduledoc """
  Calls Radarr/Sonarr API to refresh the status of a Media Source Request.

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

  alias WatchClub.Integrations.{Radarr, Sonarr}
  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.MediaSources.Servarr
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

    {status, progress} =
      compute_status_and_progress(
        request.media_source.implementation,
        request.external_resource_id
      )

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
        # Radarr/Sonarr only pull progress from the download client on their own
        # ~1 min schedule, so a 10s poll just re-reads stale bytes. While
        # downloading, nudge the *arr to refresh now so the next poll is current.
        # Best-effort: the command is async, server-coalesced, and never raises.
        if status == :downloading do
          servarr = request.media_source.implementation
          Client.refresh_monitored_downloads(servarr.base_url, servarr.api_key)
        end

        {:snooze, 10}

      # Downloaded — stop refreshing.
      true ->
        :ok
    end
  end

  defp compute_status_and_progress(%Servarr{flavor: :radarr} = servarr, movie_id) do
    movie = Radarr.get_movie_by_id!(servarr.base_url, servarr.api_key, movie_id)
    queue = Radarr.queue_details!(servarr.base_url, servarr.api_key, movie_id)
    {movie_status(movie, queue), movie_progress(movie, queue)}
  end

  defp compute_status_and_progress(%Servarr{flavor: :sonarr} = servarr, series_id) do
    episodes = Sonarr.list_episodes!(servarr.base_url, servarr.api_key, series_id)
    queue = Sonarr.queue_details!(servarr.base_url, servarr.api_key, series_id)
    {series_status(episodes, queue), series_progress(episodes, queue)}
  end

  @spec movie_status(Radarr.Movie.t(), list(Radarr.QueueResource.t())) ::
          MediaSourceRequestStatus.t()
  defp movie_status(%Radarr.Movie{} = movie, queue) do
    cond do
      movie.has_file? ->
        :downloaded

      Enum.any?(queue, &Radarr.QueueResource.blocked?/1) ->
        :needs_attention

      queue != [] ->
        :downloading

      # :not_released is moved further down since it can happen to find a movie that is not released
      # and it should still show up as downloaded
      not movie.available? ->
        :not_released

      true ->
        :searching
    end
  end

  @spec series_status(list(Sonarr.Episode.t()), list(Sonarr.QueueResource.t())) ::
          MediaSourceRequestStatus.t()
  defp series_status(episodes, queue) do
    aired_episodes = aired_regular_episodes(episodes)
    aired_episode_ids = MapSet.new(aired_episodes, & &1.id)
    queue = Enum.filter(queue, &MapSet.member?(aired_episode_ids, &1.episode_id))

    cond do
      # All aired episodes have been downloaded in Sonarr, but are not all
      # available in watch club yet
      aired_episodes != [] and Enum.all?(aired_episodes, & &1.has_file?) ->
        :downloaded

      Enum.any?(queue, &Sonarr.QueueResource.blocked?/1) ->
        :needs_attention

      queue != [] ->
        :downloading

      # :not_released is moved further down since it can happen to find a Series that is not released
      # and it should still show up as downloaded
      episodes != [] and aired_episodes == [] ->
        :not_released

      true ->
        :searching
    end
  end

  @spec movie_progress(Radarr.Movie.t(), list(Radarr.QueueResource.t())) :: float()
  defp movie_progress(%Radarr.Movie{has_file?: true}, _queue), do: 100.0

  defp movie_progress(_movie, queue) do
    queue |> Enum.map(&Radarr.QueueResource.download_progress/1) |> List.first(0.0)
  end

  @spec series_progress(list(Sonarr.Episode.t()), list(Sonarr.QueueResource.t())) :: float()
  defp series_progress(episodes, queue) do
    case aired_regular_episodes(episodes) do
      [] ->
        0.0

      aired_episodes ->
        aired_episodes
        |> Enum.map(&episode_progress(&1, queue))
        |> Enum.sum()
        |> Kernel./(length(aired_episodes))
    end
  end

  # The episodes a Content Request waits for: aired, and not specials (season 0)
  defp aired_regular_episodes(episodes) do
    now = DateTime.utc_now()

    Enum.filter(
      episodes,
      &(&1.season_number > 0 and &1.air_date_utc != nil and
          DateTime.before?(&1.air_date_utc, now))
    )
  end

  @spec episode_progress(Sonarr.Episode.t(), list(Sonarr.QueueResource.t())) :: float()
  defp episode_progress(%Sonarr.Episode{has_file?: true}, _queue), do: 100.0

  defp episode_progress(%Sonarr.Episode{} = episode, queue) do
    queue
    |> Enum.filter(&(&1.episode_id == episode.id))
    |> Enum.map(&Sonarr.QueueResource.download_progress/1)
    |> List.first(0.0)
  end
end
