defmodule WatchClub.Requests.Workers.SubmitMediaSourceRequest do
  @moduledoc """
  An Oban Job that requests a Content from a MediaSource.
  This is only called on MediaSources that support requests from the matching content type.

  The source's app adds the content when it doesn't have it yet, see
  `WatchClub.MediaSources.Servarr.App.submit_request!/2`.
  """
  use Oban.Worker,
    queue: :media_source_requests,
    max_attempts: 5

  alias WatchClub.Contents
  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.Servarr.Flavor
  alias WatchClub.Requests
  alias WatchClub.SystemActor

  @doc "Builds a submit job for one matching source of a content request."
  def new_job(content_id, media_source_id) do
    new(%{content_id: content_id, media_source_id: media_source_id})
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"content_id" => content_id, "media_source_id" => media_source_id}
      }) do
    actor = SystemActor.actor()

    source =
      MediaSources.get_media_source_by_id!(media_source_id, load: [:implementation], actor: actor)

    content = Contents.get_content_by_id!(content_id, load: [:implementation], actor: actor)
    servarr = source.implementation

    case Flavor.app(servarr.flavor).submit_request!(servarr, content) do
      {:ok, external_resource_id} ->
        Requests.create_media_source_request!(
          %{
            content_id: content_id,
            media_source_id: media_source_id,
            external_resource_id: external_resource_id
          },
          actor: actor
        )

        :ok

      # The app can't manage this content, such as a show without TVDB id on Sonarr.
      # This is permanent, so discard the job rather than retry; the Content Request
      # then reads as not found for this source.
      :unavailable ->
        {:cancel, "#{servarr.flavor} cannot manage content #{content.id}"}
    end
  end
end
