defmodule WatchClubWeb.Webhooks.ServarrController do
  @moduledoc """
  Receiver for Radarr / Sonarr webhooks. One handler serves both; the
  `/radarr/` or `/sonarr/` route segment is cosmetic, `media_source_id`
  identifies the source.

  `Test` is acked with 200 (no auth) for the server's test round-trip. Other
  events authenticate against the `Servarr`'s `webhook_secret`, then become
  ingest `Candidate`s enqueued on `CandidateIngestor`. `Download` is the only
  event that produces work today.
  """
  use WatchClubWeb, :controller

  require Logger

  alias WatchClub.Integrations.Radarr.RadarrDownloadWebhookEvent
  alias WatchClub.Integrations.Radarr.RadarrMovieFileDeleteWebhookEvent
  alias WatchClub.Integrations.Servarr.Webhook.MediaFile
  alias WatchClub.Integrations.Sonarr.SonarrDownloadWebhookEvent
  alias WatchClub.Integrations.Sonarr.SonarrEpisodeFileDeleteWebhookEvent
  alias WatchClub.MediaCatalog
  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.{EpisodeIdentity, MovieIdentity}
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor
  alias WatchClub.MediaSources.Servarr
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
  end

  defp process_webhook(%{"eventType" => "MovieFileDelete"} = params, %Servarr{flavor: :radarr} = source) do
    event = RadarrMovieFileDeleteWebhookEvent.from_api(params)
    remove_media(source, event.folder_path, event.file)
  end

  defp process_webhook(%{"eventType" => "EpisodeFileDelete"} = params, %Servarr{flavor: :sonarr} = source) do
    event = SonarrEpisodeFileDeleteWebhookEvent.from_api(params)
    remove_media(source, event.series_path, event.file)
  end

  defp process_webhook(_params, _source), do: :ok

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

  # WatchClub-local path = content folder + relative path, remapped onto our
  # disk. nil when outside this source's root, or not derivable.
  defp local_path(%Servarr{root_folder_path: root} = source, folder, %MediaFile{
         relative_path: relative_path
       })
       when is_binary(folder) and is_binary(relative_path) do
    server_path = folder |> Path.join(relative_path) |> Paths.normalize()
    root = Paths.normalize(root)

    if server_path == root or String.starts_with?(server_path, root <> "/") do
      Paths.remap_prefix(server_path, root, source.local_root_folder_path)
    end
  end

  defp local_path(_source, _folder, _file), do: nil
end
