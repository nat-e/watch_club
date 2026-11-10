defmodule WatchClub.MediaSources.Servarr.Actions.HandleWebhook do
  @moduledoc """
  Carries out a webhook from a Servarr app. The source's app translates the payload
  into actions (see `WatchClub.MediaSources.Servarr.App`): importing a downloaded
  file, removing or moving a Media, and refreshing or forgetting a Media Source
  Request.

  A Media is removed once its file is gone, except when the app deletes a whole movie or series
  with its files: it deletes them only after the webhook returns, so their Media go at once.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query
  require Logger

  alias WatchClub.Contents
  alias WatchClub.MediaCatalog
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor
  alias WatchClub.MediaSources.Servarr
  alias WatchClub.MediaSources.Servarr.Flavor
  alias WatchClub.Requests
  alias WatchClub.Requests.MediaSourceRequest
  alias WatchClub.Requests.Workers.RefreshMediaSourceRequest

  @impl true
  def run(%Ash.ActionInput{arguments: %{servarr: servarr, payload: payload}}, _opts, context) do
    opts = Ash.Context.to_opts(context)

    servarr
    |> Flavor.app(servarr.flavor).interpret_webhook!(payload)
    |> Enum.each(&run_action(servarr, &1, opts))
  end

  defp run_action(servarr, {:ingest, candidates}, _opts) do
    candidates
    |> Enum.map(&CandidateIngestor.new_job(servarr, &1))
    |> OpentelemetryOban.insert_all()
  end

  defp run_action(servarr, {:remove_media, path}, opts), do: remove_media(servarr, path, opts)

  defp run_action(servarr, {:relocate_media, from, to}, opts),
    do: relocate_media(servarr, from, to, opts)

  defp run_action(servarr, {:remove_missing_media, content_identity}, opts) do
    for media <- content_medias!(servarr, content_identity, opts),
        not File.exists?(media.path),
        do: remove_media(servarr, media.path, opts)
  end

  defp run_action(servarr, {:remove_content_media, content_identity}, opts) do
    for media <- content_medias!(servarr, content_identity, opts) do
      MediaCatalog.destroy_media!(media, opts)

      Logger.info("Media deleted: #{media.path}",
        event: :servarr_webhook_media_deleted,
        path: media.path
      )
    end
  end

  defp run_action(servarr, {:refresh_request, external_id}, opts) do
    if request = find_request(servarr, external_id, opts) do
      # Replace schedules the refresh for now, instead of waiting the next scheduled one
      # https://github.com/oban-bg/oban/blob/main/guides/learning/unique_jobs.md#replacing-values
      request.id
      |> RefreshMediaSourceRequest.new_job(scheduled_in: 1, replace: [scheduled: [:scheduled_at]])
      |> OpentelemetryOban.insert!()
    end
  end

  # The resource was removed upstream: drop the Media Source Request. The
  # Content Request survives and reads `not_found`.
  defp run_action(servarr, {:forget_request, external_id}, opts) do
    if request = find_request(servarr, external_id, opts) do
      Requests.destroy_media_source_request(request, opts)
    end
  end

  # Only the Content's Media of this source: other sources keep theirs.
  defp content_medias!(%Servarr{id: media_source_id}, content_identity, opts) do
    case Contents.get_content_by_identity!(
           content_identity,
           Keyword.merge(opts, load: [:medias], not_found_error?: false)
         ) do
      nil -> []
      content -> Enum.filter(content.medias, &(&1.media_source_id == media_source_id))
    end
  end

  defp find_request(%Servarr{id: source_id}, external_id, opts) do
    case MediaSourceRequest
         |> Ash.Query.filter(
           media_source_id == ^source_id and external_resource_id == ^external_id
         )
         |> Ash.read_one(opts) do
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

  # A same-path upgrade leaves the new file in place, so its delete event is a
  # no-op and the refreshed Media survives.
  defp remove_media(%Servarr{id: media_source_id}, path, opts) do
    with false <- File.exists?(path),
         {:ok, media} <- MediaCatalog.get_media_by_path(media_source_id, path, opts) do
      MediaCatalog.destroy_media!(media, opts)
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
  # rather than re-ingesting. The disk move already happened on the app's side.
  defp relocate_media(%Servarr{id: media_source_id}, old, new, opts) do
    with {:ok, media} <- MediaCatalog.get_media_by_path(media_source_id, old, opts),
         {:ok, _} <- MediaCatalog.change_media_path(media, %{path: new}, opts) do
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
