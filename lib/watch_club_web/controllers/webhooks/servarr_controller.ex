defmodule WatchClubWeb.Webhooks.ServarrController do
  @moduledoc """
  Controller that handles the webhook notifications from Servarr apps.

  The source's app translates each payload into actions (see
  `WatchClub.MediaSources.Servarr.App`), which this controller carries out:
  importing a downloaded file, removing or moving a Media, and refreshing or
  forgetting a Media Source Request.
  """
  use WatchClubWeb, :controller

  require Logger
  require Ash.Query

  alias WatchClub.Contents
  alias WatchClub.MediaCatalog
  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor
  alias WatchClub.MediaSources.Servarr
  alias WatchClub.MediaSources.Servarr.Flavor
  alias WatchClub.Requests
  alias WatchClub.Requests.MediaSourceRequest
  alias WatchClub.Requests.Workers.RefreshMediaSourceRequest
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
      {:ok, %{implementation: %Servarr{} = source}} ->
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

  defp process_webhook(params, %Servarr{flavor: flavor} = source) do
    source
    |> Flavor.app(flavor).interpret_webhook(params)
    |> Enum.each(&run_action(source, &1))
  end

  defp run_action(_source, {:ingest, candidates}), do: enqueue_ingest(candidates)
  defp run_action(_source, {:remove_media, path}), do: remove_media(path)
  defp run_action(_source, {:relocate_media, from, to}), do: relocate_media(from, to)

  defp run_action(_source, {:remove_missing_media, content_identity}) do
    content_identity
    |> Contents.get_content_by_identity!(
      load: [:medias],
      not_found_error?: false,
      actor: SystemActor.actor()
    )
    |> case do
      nil ->
        :ok

      content ->
        content.medias |> Enum.reject(&File.exists?(&1.path)) |> Enum.each(&remove_media(&1.path))
    end
  end

  defp run_action(source, {:refresh_request, external_id}) do
    if request = find_request(source, external_id) do
      # Replace schedules the refresh for now, instead of waiting the next scheduled one
      # https://github.com/oban-bg/oban/blob/main/guides/learning/unique_jobs.md#replacing-values
      request.id
      |> RefreshMediaSourceRequest.new_job(scheduled_in: 1, replace: [scheduled: [:scheduled_at]])
      |> OpentelemetryOban.insert!()
    end
  end

  # The resource was removed upstream: drop the Media Source Request. The
  # Content Request survives and reads `not_found`.
  defp run_action(source, {:forget_request, external_id}) do
    if request = find_request(source, external_id) do
      Requests.destroy_media_source_request(request, actor: SystemActor.actor())
    end
  end

  defp find_request(%Servarr{id: source_id}, external_id) do
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
    |> OpentelemetryOban.insert_all()
  end

  # The disk is the authority: only drop the Media when the file is actually
  # gone. A same-path upgrade leaves the new file in place, so its delete
  # event is a no-op and the refreshed Media survives.
  defp remove_media(path) do
    with false <- File.exists?(path),
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
  defp relocate_media(old, new) do
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
end
