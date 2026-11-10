defmodule WatchClub.MediaSources.Servarr.Sonarr do
  @moduledoc """
  Sonarr as a `WatchClub.MediaSources.Servarr.App`: one TV Show per Sonarr
  series, identified by its TVDB id, with one Candidate per downloaded episode.
  """
  @behaviour WatchClub.MediaSources.Servarr.App

  alias WatchClub.Contents.Content
  alias WatchClub.Contents.TvShow
  alias WatchClub.Integrations.Sonarr, as: SonarrApi
  alias WatchClub.Integrations.Sonarr.{Episode, QueueResource, Series}
  alias WatchClub.Integrations.Sonarr.SonarrDownloadWebhookEvent
  alias WatchClub.Integrations.Sonarr.SonarrEpisodeFileDeleteWebhookEvent
  alias WatchClub.Integrations.Sonarr.SonarrRenameWebhookEvent
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.EpisodeIdentity
  alias WatchClub.MediaSources.Servarr
  alias WatchClub.MediaSources.Servarr.App
  alias WatchClub.Shared.Path, as: Paths

  require Logger

  @shared_event_flags [
    :onGrab,
    :onDownload,
    :onUpgrade,
    :onRename,
    :onHealthIssue,
    :onHealthRestored,
    :onApplicationUpdate,
    :onManualInteractionRequired
  ]

  @impl true
  def media_type, do: :tv_show_episode

  @impl true
  def webhook_event_flags do
    @shared_event_flags ++
      [:onSeriesAdd, :onSeriesDelete, :onEpisodeFileDelete, :onEpisodeFileDeleteForUpgrade]
  end

  # Lists the series under this source's root folder and quality profile, then
  # their downloaded episodes.
  @impl true
  def scan(%Servarr{} = servarr) do
    Logger.info("Fetch series from Sonarr", event: :sonarr_fetch_started)

    series = SonarrApi.list_series!(servarr.base_url, servarr.api_key)

    Logger.info("#{length(series)} Series fetched from Sonarr",
      event: :sonarr_fetch_success,
      num_series: length(series)
    )

    candidates =
      series
      |> Enum.filter(&belongs_to_source?(&1, servarr))
      |> Enum.flat_map(&series_candidates(&1, servarr))

    Logger.info("Found #{length(candidates)} eligible episodes",
      event: :sonarr_scan_finished,
      num_candidates: length(candidates)
    )

    candidates
  end

  defp belongs_to_source?(%Series{} = series, %Servarr{} = servarr) do
    series.quality_profile_id == servarr.quality_profile_id and
      is_binary(series.root_folder_path) and
      Paths.normalize(series.root_folder_path) == Paths.normalize(servarr.root_folder_path)
  end

  # A failure skips this series, so the other series still import.
  defp series_candidates(%Series{} = series, %Servarr{} = servarr) do
    case SonarrApi.list_episodes(servarr.base_url, servarr.api_key, series.id) do
      {:ok, episodes} ->
        for %Episode{has_file?: true} = episode <- episodes,
            path = App.local_path(servarr, episode.file_path),
            is_binary(path) do
          episode_candidate(path, series, episode.season_number, episode.episode_number)
        end

      {:error, reason} ->
        Logger.warning("Error listing episodes for: #{series.title}",
          event: :sonarr_list_episodes_error,
          series_id: series.id,
          title: series.title,
          reason: reason
        )

        []
    end
  end

  @impl true
  def interpret_webhook(%Servarr{} = servarr, %{"eventType" => "Download"} = params) do
    event = SonarrDownloadWebhookEvent.from_api(params)

    ingest =
      case App.local_file_path(servarr, event.series_path, event.file) do
        nil ->
          Logger.warning("sonarr webhook: file doesn't match source")
          []

        # One Candidate per episode; a multi-episode file shares the one path.
        path ->
          [
            {:ingest,
             Enum.map(
               event.episodes,
               &episode_candidate(path, event, &1.season_number, &1.episode_number)
             )}
          ]
      end

    ingest ++ refresh_request(params)
  end

  def interpret_webhook(%Servarr{} = servarr, %{"eventType" => "EpisodeFileDelete"} = params) do
    event = SonarrEpisodeFileDeleteWebhookEvent.from_api(params)

    remove =
      case App.local_file_path(servarr, event.series_path, event.file) do
        nil -> []
        path -> [{:remove_media, path}]
      end

    remove ++ refresh_request(params)
  end

  def interpret_webhook(%Servarr{} = servarr, %{"eventType" => "Rename"} = params) do
    event = SonarrRenameWebhookEvent.from_api(params)
    App.relocations(servarr, event.series_path, event.renamed_files)
  end

  def interpret_webhook(_servarr, %{"eventType" => "SeriesDelete", "series" => %{"id" => id}}),
    do: [{:forget_request, id}]

  # Any other event about a series (Grab, ManualInteractionRequired…) refreshes its request.
  def interpret_webhook(_servarr, params), do: refresh_request(params)

  defp refresh_request(%{"series" => %{"id" => id}}), do: [{:refresh_request, id}]
  defp refresh_request(_params), do: []

  # `series` is a Sonarr series or a Download webhook event: both carry its ids and title.
  defp episode_candidate(path, series, season_number, episode_number) do
    %Candidate{
      path: path,
      media_type: :tv_show_episode,
      identity: %EpisodeIdentity{
        tvdb_id: series.tvdb_id,
        tmdb_id: series.tmdb_id,
        imdb_id: series.imdb_id,
        title: series.title,
        season_number: season_number,
        episode_number: episode_number
      }
    }
  end

  @impl true
  def submit_request(%Servarr{} = servarr, %Content{
        original_title: original_title,
        implementation: %TvShow{tvdb_id: tvdb_id}
      }) do
    case resolve_tvdb_id(servarr, tvdb_id, original_title) do
      {:ok, tvdb_id} ->
        case SonarrApi.get_series(servarr.base_url, servarr.api_key, tvdb_id) do
          {:ok, %Series{id: id}} ->
            {:ok, id}

          {:ok, nil} ->
            {:ok, %Series{id: id}} =
              SonarrApi.add_series(
                servarr.base_url,
                servarr.api_key,
                tvdb_id,
                original_title,
                servarr.quality_profile_id,
                servarr.root_folder_path
              )

            {:ok, id}
        end

      :unavailable ->
        :unavailable
    end
  end

  # TMDB sometimes lacks the TVDB id, so search the series by its original title
  # and take the first result.
  defp resolve_tvdb_id(servarr, nil, original_title) do
    Logger.warning("No TVDB_ID for show #{original_title}. Searching by title",
      event: :resolve_sonarr_no_tvdb_id,
      original_title: original_title
    )

    case SonarrApi.lookup_series(servarr.base_url, servarr.api_key, original_title) do
      {:ok, [%Series{tvdb_id: tvdb_id} | _]} -> {:ok, tvdb_id}
      {:ok, []} -> :unavailable
    end
  end

  defp resolve_tvdb_id(_servarr, tvdb_id, _title), do: {:ok, tvdb_id}

  @impl true
  def request_state(%Servarr{} = servarr, series_id) do
    episodes = SonarrApi.list_episodes!(servarr.base_url, servarr.api_key, series_id)
    queue = SonarrApi.queue_details!(servarr.base_url, servarr.api_key, series_id)
    {status(episodes, queue), progress(episodes, queue)}
  end

  defp status(episodes, queue) do
    now = DateTime.utc_now()

    not_released? =
      episodes != [] and
        Enum.all?(episodes, &(&1.air_date_utc && DateTime.after?(&1.air_date_utc, now)))

    cond do
      # Sonarr has every episode, even if WatchClub hasn't imported them all yet.
      episodes != [] and Enum.all?(episodes, & &1.has_file?) -> :downloaded
      Enum.any?(queue, &QueueResource.blocked?/1) -> :needs_attention
      queue != [] -> :downloading
      # After the other states: a series can be found before it starts airing.
      not_released? -> :not_released
      true -> :searching
    end
  end

  # The average progress of the aired episodes.
  defp progress(episodes, queue) do
    now = DateTime.utc_now()

    aired_count =
      Enum.count(episodes, &(&1.air_date_utc && DateTime.before?(&1.air_date_utc, now)))

    if aired_count == 0 do
      0.0
    else
      episodes
      |> Enum.map(&episode_progress(&1, queue))
      |> Enum.sum()
      |> Kernel./(aired_count)
      |> min(100.0)
    end
  end

  defp episode_progress(%Episode{has_file?: true}, _queue), do: 100.0

  defp episode_progress(%Episode{} = episode, queue) do
    queue
    |> Enum.filter(&(&1.episode_id == episode.id))
    |> Enum.map(&QueueResource.download_progress/1)
    |> List.first(0.0)
  end
end
