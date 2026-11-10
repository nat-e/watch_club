defmodule WatchClub.MediaSources.Servarr.Radarr do
  @moduledoc """
  Radarr as a `WatchClub.MediaSources.Servarr.App`: one Movie per Radarr movie,
  identified by its TMDB id.
  """
  @behaviour WatchClub.MediaSources.Servarr.App

  alias WatchClub.Contents.Content
  alias WatchClub.Integrations.Radarr, as: RadarrApi
  alias WatchClub.Integrations.Radarr.{Movie, QueueResource}
  alias WatchClub.Integrations.Radarr.RadarrDownloadWebhookEvent
  alias WatchClub.Integrations.Radarr.RadarrMovieFileDeleteWebhookEvent
  alias WatchClub.Integrations.Radarr.RadarrRenameWebhookEvent
  alias WatchClub.Integrations.Servarr.{Client, Webhook}
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.MovieIdentity
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
  def media_type, do: :movie

  @impl true
  def notifications_path, do: "/api/v3/notification"

  @impl true
  def webhook_notification(config) do
    Webhook.body(
      @shared_event_flags ++
        [:onMovieAdded, :onMovieDelete, :onMovieFileDelete, :onMovieFileDeleteForUpgrade],
      config
    )
  end

  # Lists the Radarr catalog and keeps the movies with a file under this source's
  # root folder and quality profile. Ingestion still probes the files: Radarr's
  # `mediaInfo` lacks the per-stream detail the Player needs.
  @impl true
  def scan!(%Servarr{} = servarr) do
    Logger.info("Fetch movies from Radarr", event: :radarr_fetch_started)

    movies = RadarrApi.list_movies!(servarr.base_url, servarr.api_key)

    Logger.info("#{length(movies)} movies fetched from Radarr",
      event: :radarr_fetch_success,
      num_movies: length(movies)
    )

    candidates =
      for %Movie{} = movie <- movies,
          movie.has_file? and movie.quality_profile_id == servarr.quality_profile_id,
          is_binary(movie.root_folder_path),
          Paths.normalize(movie.root_folder_path) == Paths.normalize(servarr.root_folder_path),
          path = App.local_path(servarr, movie.file_path),
          is_binary(path) do
        movie_candidate(path, movie.tmdb_id, movie.imdb_id, movie.title, movie.year)
      end

    Logger.info("Found #{length(candidates)} eligible movies",
      event: :radarr_scan_finished,
      num_candidates: length(candidates)
    )

    candidates
  end

  @impl true
  def interpret_webhook!(%Servarr{} = servarr, %{"eventType" => "Download"} = params) do
    event = RadarrDownloadWebhookEvent.from_api(params)

    ingest =
      case App.local_file_path(servarr, event.folder_path, event.file) do
        nil ->
          Logger.warning("radarr webhook: file doesn't match source")
          []

        path ->
          [
            {:ingest,
             [movie_candidate(path, event.tmdb_id, event.imdb_id, event.title, event.year)]}
          ]
      end

    ingest ++ refresh_request(params)
  end

  def interpret_webhook!(%Servarr{} = servarr, %{"eventType" => "MovieFileDelete"} = params) do
    event = RadarrMovieFileDeleteWebhookEvent.from_api(params)

    remove =
      case App.local_file_path(servarr, event.folder_path, event.file) do
        nil -> []
        path -> [{:remove_media, path}]
      end

    remove ++ refresh_request(params)
  end

  def interpret_webhook!(%Servarr{} = servarr, %{"eventType" => "Rename"} = params) do
    event = RadarrRenameWebhookEvent.from_api(params)
    App.relocations(servarr, event.folder_path, event.renamed_files)
  end

  def interpret_webhook!(_servarr, %{"eventType" => "MovieDelete", "movie" => %{"id" => id}}),
    do: [{:forget_request, id}]

  # Any other event about a movie (Grab, ManualInteractionRequired…) refreshes its request.
  def interpret_webhook!(_servarr, params), do: refresh_request(params)

  defp refresh_request(%{"movie" => %{"id" => id}}), do: [{:refresh_request, id}]
  defp refresh_request(_params), do: []

  defp movie_candidate(path, tmdb_id, imdb_id, title, year) do
    %Candidate{
      path: path,
      media_type: :movie,
      identity: %MovieIdentity{tmdb_id: tmdb_id, imdb_id: imdb_id, title: title, year: year}
    }
  end

  @impl true
  def submit_request!(%Servarr{} = servarr, %Content{external_id: external_id} = content) do
    tmdb_id = String.to_integer(external_id)

    case RadarrApi.get_movie(servarr.base_url, servarr.api_key, tmdb_id) do
      {:ok, %Movie{id: id}} ->
        {:ok, id}

      {:ok, nil} ->
        {:ok, %Movie{id: id}} =
          RadarrApi.add_movie(
            servarr.base_url,
            servarr.api_key,
            tmdb_id,
            content.original_title,
            servarr.quality_profile_id,
            servarr.root_folder_path
          )

        {:ok, id}
    end
  end

  @impl true
  def request_state!(%Servarr{} = servarr, movie_id) do
    movie = RadarrApi.get_movie_by_id!(servarr.base_url, servarr.api_key, movie_id)
    queue = RadarrApi.queue_details!(servarr.base_url, servarr.api_key, movie_id)
    status = status(movie, queue)

    # The app only pulls progress from the download client every minute or so, so
    # nudge it while downloading for the next poll to be current. Best-effort: the
    # command is async, coalesced by the server, and never raises.
    if status == :downloading do
      Client.refresh_monitored_downloads(servarr.base_url, servarr.api_key)
    end

    {status, progress(movie, queue)}
  end

  defp status(%Movie{} = movie, queue) do
    cond do
      movie.has_file? -> :downloaded
      Enum.any?(queue, &QueueResource.blocked?/1) -> :needs_attention
      queue != [] -> :downloading
      # After the other states: a movie can be found before its release date.
      not movie.available? -> :not_released
      true -> :searching
    end
  end

  defp progress(%Movie{has_file?: true}, _queue), do: 100.0

  defp progress(_movie, queue) do
    queue |> Enum.map(&QueueResource.download_progress/1) |> List.first(0.0)
  end
end
