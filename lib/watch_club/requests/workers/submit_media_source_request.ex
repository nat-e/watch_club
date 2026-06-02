defmodule WatchClub.Requests.Workers.SubmitMediaSourceRequest do
  @moduledoc """
  Adds (or adopts) one `(content, media_source)` in its upstream system, then
  records the `MediaSourceRequest`. The `:create` action recomputes the
  initial `state` from the *arr (via `RefreshState`), so this worker only needs
  to get the resource into the *arr and hand back its id.

  Lets anything unexpected — including a `*arr` being down — crash; Oban
  retries, and once attempts exhaust the Content Request simply has no Media
  Source Request for that source (it reads as not found). Re-runs are safe:
  the add path adopts an existing resource and `:create` upserts.

  Enqueued (one per matching source) by `CreateMediaSourceRequests` when a
  Content Request is created. Not deduplicated at enqueue time — the same
  `(content, media_source)` can be submitted more than once (concurrent
  requests for the same content, or a re-request). That is harmless: the
  `:create` upsert on `unique_content_source` collapses them to one row and
  the add path adopts an existing resource.
  """
  use Oban.Worker,
    queue: :media_source_requests,
    max_attempts: 5

  alias WatchClub.Contents
  alias WatchClub.Contents.Content
  alias WatchClub.Integrations.{Radarr, Sonarr}
  alias WatchClub.Integrations.Radarr.Movie
  alias WatchClub.Integrations.Sonarr.Series
  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.Servarr
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

    content = Contents.get_content_by_id!(content_id, load: [:tv_show], actor: actor)

    Requests.create_media_source_request!(
      %{
        content_id: content_id,
        media_source_id: media_source_id,
        external_resource_id: get_or_create_on_servarr(source.implementation, content)
      },
      actor: actor
    )

    :ok
  end

  # Returns the *arr's id for the resource, adding it if absent.
  defp get_or_create_on_servarr(%Servarr{flavor: :radarr} = servarr, %Content{
         external_id: external_id,
         original_title: title
       }) do
    tmdb_id = String.to_integer(external_id)

    case Radarr.get_movie(servarr.base_url, servarr.api_key, tmdb_id) do
      {:ok, %Movie{id: id}} ->
        id

      {:ok, nil} ->
        {:ok, %Movie{id: id}} =
          Radarr.add_movie(
            servarr.base_url,
            servarr.api_key,
            tmdb_id,
            title,
            servarr.quality_profile_id,
            servarr.root_folder_path
          )

        id
    end
  end

  defp get_or_create_on_servarr(%Servarr{flavor: :sonarr} = servarr, %Content{
         original_title: title,
         tv_show: %{tvdb_id: tvdb_id}
       }) do
    case Sonarr.get_series(servarr.base_url, servarr.api_key, tvdb_id) do
      {:ok, %Series{id: id}} ->
        id

      {:ok, nil} ->
        {:ok, %Series{id: id}} =
          Sonarr.add_series(
            servarr.base_url,
            servarr.api_key,
            tvdb_id,
            title,
            servarr.quality_profile_id,
            servarr.root_folder_path
          )

        id
    end
  end
end
