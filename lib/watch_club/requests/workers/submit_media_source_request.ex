defmodule WatchClub.Requests.Workers.SubmitMediaSourceRequest do
  @moduledoc """
  An Oban Job that requests a Content from a MediaSource.
  This is only called on MediaSources that support requests (Radarr/Sonarr) from the matching content type.

  This first checks if the content already exists, and add it to Radarr/Sonarr if not.
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

  require Logger

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

    case get_or_create_on_servarr(source.implementation, content) do
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

      # The show has no TVDB cross-reference, so Sonarr can't manage it. This is
      # permanent, so discard the job (no retries) rather than crash-and-exhaust;
      # the Content Request then reads as not found for this source.
      :unavailable ->
        {:cancel, "No TVDB match for content #{content.id}; Sonarr cannot manage it"}
    end
  end

  # Returns `{:ok, arr_id}` for the resource, adding it if absent, or
  # `:unavailable` when the show cannot be managed (no TVDB id resolvable).
  defp get_or_create_on_servarr(%Servarr{flavor: :radarr} = servarr, %Content{
         external_id: external_id,
         original_title: title
       }) do
    tmdb_id = String.to_integer(external_id)

    case Radarr.get_movie(servarr.base_url, servarr.api_key, tmdb_id) do
      {:ok, %Movie{id: id}} ->
        {:ok, id}

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

        {:ok, id}
    end
  end

  defp get_or_create_on_servarr(%Servarr{flavor: :sonarr} = servarr, %Content{
         original_title: original_title,
         tv_show: %{tvdb_id: tvdb_id}
       }) do
    case resolve_tvdb_id(servarr, tvdb_id, original_title) do
      {:ok, tvdb_id} ->
        series_id =
          case Sonarr.get_series(servarr.base_url, servarr.api_key, tvdb_id) do
            {:ok, %Series{id: id}} ->
              id

            {:ok, nil} ->
              {:ok, %Series{id: id}} =
                Sonarr.add_series(
                  servarr.base_url,
                  servarr.api_key,
                  tvdb_id,
                  original_title,
                  servarr.quality_profile_id,
                  servarr.root_folder_path
                )

              id
          end

        {:ok, series_id}

      :unavailable ->
        :unavailable
    end
  end

  # Sometimes the TVDB id is missing in TMDB and we need to search the Series by
  # its original title instead
  # At the moment, we take the first result blindly, if that causes issues we could try better matching
  # with the release date in the future.
  defp resolve_tvdb_id(servarr, nil, original_title) do
    Logger.info("No TVDB_ID for show #{original_title}. Searching by title")

    case Sonarr.lookup_series(servarr.base_url, servarr.api_key, original_title) do
      {:ok, [%Series{tvdb_id: tvdb_id} | _]} -> {:ok, tvdb_id}
      {:ok, []} -> :unavailable
    end
  end

  defp resolve_tvdb_id(_servarr, tvdb_id, _title), do: {:ok, tvdb_id}
end
