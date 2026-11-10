defmodule WatchClub.MediaSources.Servarr.Actions.HandleWebhook do
  @moduledoc """
  Carries out a webhook from a Servarr app. The source's app translates the payload
  into actions (see `WatchClub.MediaSources.Servarr.App`): importing a downloaded
  file, removing or moving a Media, and refreshing or forgetting a Media Source
  Request.

  The disk is the authority: a Media is only removed when its file is gone.
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
  alias WatchClub.Shared.Path, as: Paths

  @impl true
  def run(%Ash.ActionInput{arguments: %{servarr: servarr, payload: payload}}, _opts, context) do
    opts = Ash.Context.to_opts(context)

    servarr
    |> Flavor.app(servarr.flavor).interpret_webhook!(payload)
    |> Enum.each(&run_action(servarr, &1, opts))
  end

  defp run_action(_servarr, {:ingest, candidates}, _opts) do
    candidates
    |> Enum.map(&CandidateIngestor.new_job/1)
    |> OpentelemetryOban.insert_all()
  end

  defp run_action(_servarr, {:remove_media, path}, opts), do: remove_media(path, opts)
  defp run_action(_servarr, {:relocate_media, from, to}, opts), do: relocate_media(from, to, opts)

  # Only the Content's Media under this source's root folder: other sources keep theirs.
  defp run_action(servarr, {:remove_missing_media, content_identity}, opts) do
    root = Paths.normalize(servarr.local_root_folder_path || servarr.root_folder_path) <> "/"

    case Contents.get_content_by_identity!(
           content_identity,
           Keyword.merge(opts, load: [:medias], not_found_error?: false)
         ) do
      nil ->
        :ok

      content ->
        for media <- content.medias,
            String.starts_with?(media.path, root),
            not File.exists?(media.path),
            do: remove_media(media.path, opts)
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
  defp remove_media(path, opts) do
    with false <- File.exists?(path),
         {:ok, media} <- MediaCatalog.get_media_by_path(path, opts) do
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
  defp relocate_media(old, new, opts) do
    with {:ok, media} <- MediaCatalog.get_media_by_path(old, opts),
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
