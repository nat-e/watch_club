defmodule WatchClub.Integrations.Sonarr do
  @moduledoc """
  Sonarr v3 API facade. Owns Sonarr's catalog endpoints (`/api/v3/series`
  plus per-series `/api/v3/episode`) and their response parsing. Every
  other endpoint is flavor-agnostic and lives on `Servarr.Client`.
  """

  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.Integrations.Servarr.QueueItem
  alias WatchClub.Integrations.Sonarr.{Episode, Series}

  @doc """
  Returns every series in the Sonarr library (no server-side filtering;
  callers filter client-side). Retries transient errors.
  """
  @spec list_series(String.t(), String.t()) :: {:ok, [Series.t()]} | {:error, term()}
  def list_series(base_url, api_key) do
    case Client.get(base_url, api_key, "/api/v3/series", retry: :transient) do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &Series.from_api/1)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @doc """
  Returns the episodes of one Sonarr series, with their embedded episode
  files (`includeEpisodeFile=true`). Retries transient errors.
  """
  @spec list_episodes(String.t(), String.t(), integer()) ::
          {:ok, [Episode.t()]} | {:error, term()}
  def list_episodes(base_url, api_key, series_id) when is_integer(series_id) do
    path = "/api/v3/episode?seriesId=#{series_id}&includeEpisodeFile=true"

    case Client.get(base_url, api_key, path, retry: :transient) do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &Episode.from_api/1)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @doc """
  Returns the `Series` for `tvdb_id` if Sonarr already has it, else `nil`.
  Used to adopt a series rather than re-adding it.
  """
  @spec get_series(String.t(), String.t(), integer()) ::
          {:ok, Series.t() | nil} | {:error, term()}
  def get_series(base_url, api_key, tvdb_id) when is_integer(tvdb_id) do
    case Client.get(base_url, api_key, "/api/v3/series?tvdbId=#{tvdb_id}", retry: :transient) do
      {:ok, [series | _]} when is_map(series) -> {:ok, Series.from_api(series)}
      {:ok, []} -> {:ok, nil}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @doc """
  Adds a series to Sonarr — fully monitored, on the given quality profile +
  root folder — and triggers a search for missing episodes. No lookup
  needed: Sonarr fills the rest of the metadata from `tvdb_id`, so only the
  title is sent alongside it. Returns the created `Series`.
  """
  @spec add_series(String.t(), String.t(), integer(), String.t(), integer(), String.t()) ::
          {:ok, Series.t()} | {:error, term()}
  def add_series(base_url, api_key, tvdb_id, title, quality_profile_id, root_folder_path) do
    body = %{
      "tvdbId" => tvdb_id,
      "title" => title,
      "qualityProfileId" => quality_profile_id,
      "rootFolderPath" => root_folder_path,
      "monitored" => true,
      "monitorNewItems" => "all",
      "addOptions" => %{"searchForMissingEpisodes" => true}
    }

    case Client.post(base_url, api_key, "/api/v3/series", body) do
      {:ok, %{"id" => _} = series} -> {:ok, Series.from_api(series)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @doc """
  Fetches one `Series` by its Sonarr id (`GET /api/v3/series/{id}`).
  `{:error, :not_found}` when the series is no longer in the library.
  """
  @spec get_series_by_id(String.t(), String.t(), integer()) ::
          {:ok, Series.t()} | {:error, term()}
  def get_series_by_id(base_url, api_key, series_id) when is_integer(series_id) do
    case Client.get(base_url, api_key, "/api/v3/series/#{series_id}", retry: :transient) do
      {:ok, series} when is_map(series) -> {:ok, Series.from_api(series)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @doc """
  Returns the download-queue `QueueItem`s for one series
  (`GET /api/v3/queue/details?seriesId=`). An empty list means nothing is
  queued or downloading for the series. Retries transient errors.
  """
  @spec queue_details(String.t(), String.t(), integer()) ::
          {:ok, [QueueItem.t()]} | {:error, term()}
  def queue_details(base_url, api_key, series_id) when is_integer(series_id) do
    case Client.get(base_url, api_key, "/api/v3/queue/details?seriesId=#{series_id}",
           retry: :transient
         ) do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &QueueItem.from_api/1)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end
end
