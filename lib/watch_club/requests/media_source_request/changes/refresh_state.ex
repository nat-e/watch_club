defmodule WatchClub.Requests.MediaSourceRequest.Changes.RefreshState do
  @moduledoc """
  Recomputes a `MediaSourceRequest`'s `state` from the *arr's current truth:
  the movie/series record plus its download queue. Used by both `:create` and
  `:refresh_status`, so a freshly-submitted request and a webhook/poll refresh
  derive state the same way.

  Best-effort: if the source or resource can't be fetched the state is left
  as-is (the row keeps its default/previous value). A genuinely deleted
  resource is handled by the delete webhook, not here.
  """
  use Ash.Resource.Change

  alias WatchClub.Integrations.{Radarr, Sonarr}
  alias WatchClub.Integrations.Radarr.Movie
  alias WatchClub.Integrations.Servarr.QueueItem
  alias WatchClub.Integrations.Sonarr.Series
  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.Servarr
  alias WatchClub.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    # The derivation makes an HTTP call, so run it outside the transaction
    # (mirrors `Servarr`'s webhook-registration change) rather than holding the
    # transaction open for the round-trip.
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      media_source_id = Ash.Changeset.get_attribute(changeset, :media_source_id)
      external_resource_id = Ash.Changeset.get_attribute(changeset, :external_resource_id)

      with {:ok, %{implementation: %Servarr{} = servarr}} <-
             MediaSources.get_media_source_by_id(media_source_id,
               load: [:implementation],
               actor: SystemActor.actor()
             ),
           {:ok, state} <- compute_state(servarr, external_resource_id) do
        Ash.Changeset.force_change_attribute(changeset, :state, state)
      else
        _ -> changeset
      end
    end)
  end

  defp compute_state(%Servarr{flavor: :radarr} = servarr, movie_id) do
    with {:ok, movie} <- Radarr.get_movie_by_id(servarr.base_url, servarr.api_key, movie_id),
         {:ok, queue} <- Radarr.queue_details(servarr.base_url, servarr.api_key, movie_id) do
      {:ok, movie_state(movie, queue)}
    end
  end

  defp compute_state(%Servarr{flavor: :sonarr} = servarr, series_id) do
    with {:ok, series} <- Sonarr.get_series_by_id(servarr.base_url, servarr.api_key, series_id),
         {:ok, queue} <- Sonarr.queue_details(servarr.base_url, servarr.api_key, series_id) do
      {:ok, series_state(series, queue)}
    end
  end

  # The one file is what matters; a blocked/queued item only matters before it
  # lands.
  defp movie_state(%Movie{} = movie, queue) do
    cond do
      movie.has_file? -> :downloaded
      queue_blocked?(queue) -> :needs_attention
      queue != [] -> :downloading
      not movie.available? -> :not_released
      true -> :submitted
    end
  end

  # `episode_count` is Sonarr's count of *aired, monitored* episodes (the
  # completion denominator); `file_count` is episode files. All aired present
  # wins outright (an in-flight upgrade doesn't undo "downloaded"); an active
  # queue means more are coming; some-but-not-all idle is partial.
  #
  # `not_released` keys off Sonarr's own `status` ("upcoming"), not
  # `episode_count == 0`: for a few tens of ms after an add the statistics
  # aren't computed yet, so an aired show momentarily reports
  # `episode_count == 0`. Treating that as not-released would flash "Not
  # released" on a just-requested show; instead an empty count falls through to
  # `submitted` (which reads as "Queued" in its grace window), and only a
  # genuine `upcoming` series — a signal Sonarr sets immediately — is
  # not-released.
  #
  # Caveat: `file_count` counts files, so multi-episode files undercount and
  # extra/special files can overcount — this is a heuristic, not exact. The
  # user-facing `completed` is gated by WatchClub Media, not by this state.
  defp series_state(
         %Series{status: status, episode_count: episode_count, episode_file_count: file_count},
         queue
       ) do
    cond do
      episode_count > 0 and file_count >= episode_count -> :downloaded
      queue_blocked?(queue) -> :needs_attention
      queue != [] -> :downloading
      file_count > 0 -> :partially_downloaded
      status == "upcoming" -> :not_released
      true -> :submitted
    end
  end

  defp queue_blocked?(queue), do: Enum.any?(queue, &QueueItem.blocked?/1)
end
