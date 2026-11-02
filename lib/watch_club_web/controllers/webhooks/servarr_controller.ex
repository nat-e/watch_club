defmodule WatchClubWeb.Webhooks.ServarrController do
  @moduledoc """
  Controller that handles the webhook notifications from Radarr and Sonarr.

  Supported events:
  - Rename: A file has been renamed on Radarr/Sonarr, we update the Media path in Watch Club
  - EpisodeFileDelete / MovieFileDelete: A file has been deleted on Radarr/Sonarr, we delete
    the Media in Watch Club
  - Grab / Download / ManualInteractionRequired: The status of a request has changed on Servarr,
    we simply schedule a MSR refresh to be done in an Oban job.
  """
  use WatchClubWeb, :controller

  require Logger
  require Ash.Query

  alias WatchClub.Integrations.Radarr.RadarrDownloadWebhookEvent
  alias WatchClub.Integrations.Radarr.RadarrMovieFileDeleteWebhookEvent
  alias WatchClub.Integrations.Radarr.RadarrRenameWebhookEvent
  alias WatchClub.Integrations.Servarr.Webhook.MediaFile
  alias WatchClub.Integrations.Servarr.Webhook.RenamedFile
  alias WatchClub.Integrations.Sonarr.SonarrDownloadWebhookEvent
  alias WatchClub.Integrations.Sonarr.SonarrEpisodeFileDeleteWebhookEvent
  alias WatchClub.Integrations.Sonarr.SonarrRenameWebhookEvent
  alias WatchClub.MediaCatalog
  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.{EpisodeIdentity, MovieIdentity}
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor
  alias WatchClub.MediaSources.Servarr
  alias WatchClub.Requests
  alias WatchClub.Requests.MediaSourceRequest
  alias WatchClub.Requests.Workers.RefreshMediaSourceRequest
  alias WatchClub.Shared.Path, as: Paths
  alias WatchClub.SystemActor

  @token_header "x-watchclub-token"

  # MovieAdded is useless since we got the response anyway, and it creates
  # warnings since it's received before the request is persisted in DB most of the time
  @ignored_event_types ["MovieAdded", "HealthRestored", "Health", "Test"]

  def handle(conn, %{"eventType" => event_type}) when event_type in @ignored_event_types do
    Logger.info("Servarr webhook event ignored: #{event_type}",
      event: :servarr_webhook_ignored,
      event_type: event_type
    )

    json(conn, %{ok: true})
  end

  def handle(conn, %{"eventType" => event_type, "media_source_id" => id} = params) do
    Logger.metadata(
      event_type: event_type,
      media_source_id: id
    )

    Logger.info("Servarr webhook received: #{event_type}", event: :servarr_webhook_received)

    with {:ok, source} <- fetch_source(id),
         :ok <- verify_token(conn, source) do
      process_webhook(params, source)

      json(conn, %{ok: true})
    else
      _ -> conn |> put_status(:unauthorized) |> json(%{ok: false})
    end
  end

  def handle(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{ok: false, error: "missing eventType"})
  end

  defp fetch_source(media_source_id) do
    case MediaSources.get_media_source_by_id(media_source_id,
           load: [:implementation],
           actor: SystemActor.actor()
         ) do
      {:ok, %{source_type: type, implementation: %Servarr{} = source}}
      when type in [:radarr, :sonarr] ->
        {:ok, source}

      _ ->
        Logger.warning("Media source not found: #{media_source_id}",
          event: :servarr_webhook_media_source_not_found
        )

        :error
    end
  end

  defp verify_token(conn, %Servarr{webhook_secret: secret}) do
    with [provided] <- get_req_header(conn, @token_header),
         true <- Plug.Crypto.secure_compare(provided, secret) do
      :ok
    else
      _ ->
        Logger.warning("Invalid Servarr webhook token", event: :servarr_webhook_invalid_token)
        :error
    end
  end

  defp process_webhook(%{"eventType" => "Download"} = params, %Servarr{flavor: :radarr} = source) do
    event = RadarrDownloadWebhookEvent.from_api(params)

    case local_path(source, event.folder_path, event.file) do
      nil ->
        Logger.warning("radarr webhook: file doesn't match source")
        :ok

      path ->
        enqueue_ingest([
          %Candidate{
            path: path,
            media_type: :movie,
            identity: %MovieIdentity{
              tmdb_id: event.tmdb_id,
              imdb_id: event.imdb_id,
              title: event.title,
              year: event.year
            }
          }
        ])
    end

    refresh_request(source, params)
  end

  defp process_webhook(%{"eventType" => "Download"} = params, %Servarr{flavor: :sonarr} = source) do
    event = SonarrDownloadWebhookEvent.from_api(params)

    case local_path(source, event.series_path, event.file) do
      nil ->
        Logger.warning("sonarr webhook: file doesn't match source")
        :ok

      # One Candidate per episode; a multi-episode file shares the one path.
      path ->
        event.episodes
        |> Enum.map(fn episode ->
          %Candidate{
            path: path,
            media_type: :tv_show_episode,
            identity: %EpisodeIdentity{
              tvdb_id: event.tvdb_id,
              tmdb_id: event.tmdb_id,
              imdb_id: event.imdb_id,
              title: event.title,
              season_number: episode.season_number,
              episode_number: episode.episode_number
            }
          }
        end)
        |> enqueue_ingest()
    end

    refresh_request(source, params)
  end

  defp process_webhook(
         %{"eventType" => "MovieFileDelete"} = params,
         %Servarr{flavor: :radarr} = source
       ) do
    event = RadarrMovieFileDeleteWebhookEvent.from_api(params)
    remove_media(source, event.folder_path, event.file)
    refresh_request(source, params)
  end

  defp process_webhook(
         %{"eventType" => "EpisodeFileDelete"} = params,
         %Servarr{flavor: :sonarr} = source
       ) do
    event = SonarrEpisodeFileDeleteWebhookEvent.from_api(params)
    remove_media(source, event.series_path, event.file)
    refresh_request(source, params)
  end

  defp process_webhook(%{"eventType" => "Rename"} = params, %Servarr{flavor: :radarr} = source) do
    event = RadarrRenameWebhookEvent.from_api(params)
    move_renamed_files(source, event.folder_path, event.renamed_files)
  end

  defp process_webhook(%{"eventType" => "Rename"} = params, %Servarr{flavor: :sonarr} = source) do
    event = SonarrRenameWebhookEvent.from_api(params)
    move_renamed_files(source, event.series_path, event.renamed_files)
  end

  # The movie / series was removed upstream — drop the Media Source Request
  # (the Content Request survives and reads `not_found`).
  defp process_webhook(
         %{"eventType" => "MovieDelete"} = params,
         %Servarr{flavor: :radarr} = source
       ) do
    destroy_request(source, params)
  end

  defp process_webhook(
         %{"eventType" => "SeriesDelete"} = params,
         %Servarr{flavor: :sonarr} = source
       ) do
    destroy_request(source, params)
  end

  # Any other event for the resource (Grab, ManualInteractionRequired, …) just
  # triggers a reconcile; events with no resource (HealthIssue, …) no-op.
  defp process_webhook(params, %Servarr{} = source) do
    refresh_request(source, params)
  end

  defp refresh_request(%Servarr{} = source, params) do
    if request = find_request(source, params) do
      # Replace schedules the refresh for now, instead of waiting the next scheduled one
      # https://github.com/oban-bg/oban/blob/main/guides/learning/unique_jobs.md#replacing-values
      request.id
      |> RefreshMediaSourceRequest.new_job(scheduled_in: 1, replace: [scheduled: [:scheduled_at]])
      |> Oban.insert!()
    end
  end

  defp destroy_request(%Servarr{} = source, params) do
    if request = find_request(source, params) do
      Requests.destroy_media_source_request(request, actor: SystemActor.actor())
    end
  end

  defp find_request(%Servarr{id: source_id, flavor: :radarr}, %{
         "movie" => %{"id" => radarr_movie_id}
       }) do
    find_request_with_id(source_id, radarr_movie_id)
  end

  defp find_request(%Servarr{id: source_id, flavor: :sonarr}, %{
         "series" => %{"id" => sonarr_movie_id}
       }) do
    find_request_with_id(source_id, sonarr_movie_id)
  end

  # This is most likely a Health or other webhook not tied to a movie/series, ignore
  defp find_request(_, _) do
    Logger.info("Servarr webhook ignored, no resource targetted",
      event: :servarr_webhook_no_resource
    )

    nil
  end

  defp find_request_with_id(source_id, external_id) do
    case MediaSourceRequest
         |> Ash.Query.filter(
           media_source_id == ^source_id and external_resource_id == ^external_id
         )
         |> Ash.read_one(actor: SystemActor.actor()) do
      {:ok, %MediaSourceRequest{} = request} ->
        request

      {:ok, nil} ->
        Logger.warning("Media Server Request not found: #{external_id}",
          event: :servarr_webhook_request_not_found,
          external_id: external_id
        )

        nil
    end
  end

  defp enqueue_ingest(candidates) do
    candidates
    |> Enum.map(&CandidateIngestor.new_job/1)
    |> Oban.insert_all()
  end

  # The disk is the authority: only drop the Media when the file is actually
  # gone. A same-path upgrade leaves the new file in place, so its delete
  # event is a no-op and the refreshed Media survives.
  defp remove_media(source, folder, file) do
    with path when is_binary(path) <- local_path(source, folder, file),
         false <- File.exists?(path),
         {:ok, media} <- MediaCatalog.get_media_by_path(path, actor: SystemActor.actor()) do
      MediaCatalog.destroy_media!(media, actor: SystemActor.actor())
      Logger.info("Media deleted: #{path}", event: :servarr_webhook_media_deleted, path: path)
    else
      _ ->
        Logger.warning("Could not delete media, file not found",
          event: :servarr_webhook_file_not_found
        )

        :ok
    end
  end

  # A rename moves bytes in place, so relocate the existing Media old → new
  # rather than re-ingesting. The disk move already happened on the *arr side.
  defp move_renamed_files(source, folder, renamed_files) when is_binary(folder) do
    Enum.each(renamed_files, &move_renamed_file(source, folder, &1))
  end

  defp move_renamed_files(_source, _folder, _renamed_files), do: :ok

  defp move_renamed_file(source, folder, %RenamedFile{
         previous_path: previous,
         relative_path: relative
       })
       when is_binary(previous) and is_binary(relative) do
    relocate_media(to_local(source, previous), to_local(source, Path.join(folder, relative)))
  end

  defp move_renamed_file(_source, _folder, _file), do: :ok

  defp relocate_media(old, new) when is_binary(old) and is_binary(new) and old != new do
    with {:ok, media} <- MediaCatalog.get_media_by_path(old, actor: SystemActor.actor()),
         {:ok, _} <-
           MediaCatalog.change_media_path(media, %{path: new}, actor: SystemActor.actor()) do
      Logger.info("Media path renamed: #{new}",
        event: :servarr_webhook_media_renamed,
        from: old,
        to: new
      )

      :ok
    else
      _ ->
        Logger.warning("Could not rename media, file not found",
          event: :servarr_webhook_file_not_found
        )

        :ok
    end
  end

  defp relocate_media(_old, _new), do: :ok

  # WatchClub-local path of a content folder + relative path; nil when not
  # derivable.
  defp local_path(source, folder, %MediaFile{relative_path: relative_path})
       when is_binary(folder) and is_binary(relative_path) do
    to_local(source, Path.join(folder, relative_path))
  end

  defp local_path(_source, _folder, _file), do: nil

  # Maps a server-side absolute path onto WatchClub's disk; nil when the path
  # is outside this source's root folder.
  defp to_local(%Servarr{root_folder_path: root} = source, server_path)
       when is_binary(server_path) do
    server_path = Paths.normalize(server_path)
    root = Paths.normalize(root)

    if server_path == root or String.starts_with?(server_path, root <> "/") do
      Paths.remap_prefix(server_path, root, source.local_root_folder_path)
    end
  end

  defp to_local(_source, _server_path), do: nil
end
