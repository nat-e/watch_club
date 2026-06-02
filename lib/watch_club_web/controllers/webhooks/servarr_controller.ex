defmodule WatchClubWeb.Webhooks.ServarrController do
  @moduledoc """
  Receiver for Radarr / Sonarr webhooks. One handler serves both; the
  `/radarr/` or `/sonarr/` route segment is cosmetic, `media_source_id`
  identifies the source.

  `Test` is acked with 200 (no auth) for the server's test round-trip. Other
  events authenticate against the `Servarr`'s `webhook_secret`, then do two
  things: the Media side (ingest/remove/relocate files) and the request side —
  any event enqueues a `RefreshMediaSourceRequest` that reconciles the Media
  Source Request's state against the *arr's current truth, except deletes,
  which drop the request.
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

  def handle(conn, %{"eventType" => "Test"}), do: json(conn, %{ok: true})

  def handle(conn, %{"eventType" => event_type, "media_source_id" => id} = params) do
    with {:ok, source} <- fetch_source(id),
         :ok <- verify_token(conn, source) do
      Logger.info("servarr webhook",
        flavor: source.flavor,
        event_type: event_type,
        media_source_id: id,
        payload: Map.drop(params, ["media_source_id"])
      )

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
        :error
    end
  end

  defp verify_token(conn, %Servarr{webhook_secret: secret}) do
    with [provided] <- get_req_header(conn, @token_header),
         true <- Plug.Crypto.secure_compare(provided, secret) do
      :ok
    else
      _ -> :error
    end
  end

  defp process_webhook(%{"eventType" => "Download"} = params, %Servarr{flavor: :radarr} = source) do
    event = RadarrDownloadWebhookEvent.from_api(params)

    case local_path(source, event.folder_path, event.file) do
      nil ->
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
    relocate_renamed_files(source, event.folder_path, event.renamed_files)
  end

  defp process_webhook(%{"eventType" => "Rename"} = params, %Servarr{flavor: :sonarr} = source) do
    event = SonarrRenameWebhookEvent.from_api(params)
    relocate_renamed_files(source, event.series_path, event.renamed_files)
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
  defp process_webhook(params, %Servarr{} = source), do: refresh_request(source, params)

  # ─── Media Source Request state ──────────────────────────────────────────
  #
  # The state is reconciled from the *arr's current truth, never driven by the
  # event — so any webhook just enqueues a refresh for the resource, if
  # WatchClub requested it. Matched by the id stored at submit/adopt.

  # Only enqueue when WatchClub actually requested this resource — most *arr
  # webhooks are for library content nobody requested here, which we ignore.
  defp refresh_request(%Servarr{} = source, params) do
    if request = find_request(source, params) do
      request.id |> RefreshMediaSourceRequest.new_job() |> Oban.insert!()
    end
  end

  defp destroy_request(%Servarr{} = source, params) do
    if request = find_request(source, params) do
      Requests.destroy_media_source_request(request, actor: SystemActor.actor())
    end
  end

  defp find_request(%Servarr{id: source_id, flavor: flavor}, params) do
    with arr_id when is_integer(arr_id) <- get_in(params, [arr_resource_key(flavor), "id"]),
         {:ok, %MediaSourceRequest{} = request} <-
           MediaSourceRequest
           |> Ash.Query.filter(media_source_id == ^source_id and external_resource_id == ^arr_id)
           |> Ash.read_one(actor: SystemActor.actor()) do
      request
    else
      _ -> nil
    end
  end

  defp arr_resource_key(:radarr), do: "movie"
  defp arr_resource_key(:sonarr), do: "series"

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
      MediaCatalog.destroy_media(media, actor: SystemActor.actor())
    else
      _ -> :ok
    end
  end

  # A rename moves bytes in place, so relocate the existing Media old → new
  # rather than re-ingesting. The disk move already happened on the *arr side.
  defp relocate_renamed_files(source, folder, renamed_files) when is_binary(folder) do
    Enum.each(renamed_files, &relocate_renamed_file(source, folder, &1))
  end

  defp relocate_renamed_files(_source, _folder, _renamed_files), do: :ok

  defp relocate_renamed_file(source, folder, %RenamedFile{
         previous_path: previous,
         relative_path: relative
       })
       when is_binary(previous) and is_binary(relative) do
    relocate_media(to_local(source, previous), to_local(source, Path.join(folder, relative)))
  end

  defp relocate_renamed_file(_source, _folder, _file), do: :ok

  defp relocate_media(old, new) when is_binary(old) and is_binary(new) and old != new do
    with {:ok, media} <- MediaCatalog.get_media_by_path(old, actor: SystemActor.actor()),
         {:ok, _} <-
           MediaCatalog.change_media_path(media, %{path: new}, actor: SystemActor.actor()) do
      :ok
    else
      _ -> :ok
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
