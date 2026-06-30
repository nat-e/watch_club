defmodule WatchClub.Integrations.Sonarr do
  @moduledoc """
  Sonarr v3 API client
  """

  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.Integrations.Sonarr.{Episode, QueueResource, Series}

  @doc """
  Returns every series in the Sonarr library (no server-side filtering;
  callers filter client-side).
  """
  @spec list_series(String.t(), String.t()) :: {:ok, list(Series.t())} | {:error, term()}
  def list_series(base_url, api_key) do
    case Client.get(base_url, api_key, "/api/v3/series") do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &Series.from_api/1)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @spec list_series!(String.t(), String.t()) :: list(Series.t())
  def list_series!(base_url, api_key) do
    {:ok, series} = list_series(base_url, api_key)
    series
  end

  @doc """
  Returns the episodes of one Sonarr series, with their embedded episode
  files.
  """
  @spec list_episodes(String.t(), String.t(), integer()) ::
          {:ok, [Episode.t()]} | {:error, term()}
  def list_episodes(base_url, api_key, series_id) when is_integer(series_id) do
    case Client.get(base_url, api_key, "/api/v3/episode",
           params: %{seriesId: series_id, includeEpisodeFile: true}
         ) do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &Episode.from_api/1)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @spec list_episodes!(String.t(), String.t(), integer()) :: list(Episode.t())
  def list_episodes!(base_url, api_key, series_id) when is_integer(series_id) do
    {:ok, episodes} = list_episodes(base_url, api_key, series_id)
    episodes
  end

  @doc """
  Returns the `Series` for `tvdb_id` if Sonarr already has it, else `nil`.
  """
  @spec get_series(String.t(), String.t(), integer()) ::
          {:ok, Series.t() | nil} | {:error, term()}
  def get_series(base_url, api_key, tvdb_id) when is_integer(tvdb_id) do
    case Client.get(base_url, api_key, "/api/v3/series", params: %{tvdbId: tvdb_id}) do
      {:ok, [series | _]} when is_map(series) -> {:ok, Series.from_api(series)}
      {:ok, []} -> {:ok, nil}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @doc """
  Search for a Series on TVDB by free-form text.
  Original title yields the best result.
  """
  @spec lookup_series(String.t(), String.t(), String.t()) ::
          {:ok, [Series.t()]} | {:error, term()}
  def lookup_series(base_url, api_key, query) do
    with {:ok, results} <-
           Client.get(base_url, api_key, "/api/v3/series/lookup", params: %{term: query}) do
      {:ok, results |> Enum.map(&Series.from_api(&1))}
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
  Fetches one `Series` by its Sonarr id.
  `{:error, :not_found}` when the series is no longer in the library.
  """
  @spec get_series_by_id(String.t(), String.t(), integer()) ::
          {:ok, Series.t()} | {:error, term()}
  def get_series_by_id(base_url, api_key, series_id) when is_integer(series_id) do
    case Client.get(base_url, api_key, "/api/v3/series/#{series_id}") do
      {:ok, series} when is_map(series) -> {:ok, Series.from_api(series)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @doc """
  Returns the download-queue `QueueResource`s for one series.
  """
  @spec queue_details(String.t(), String.t(), integer()) ::
          {:ok, [QueueResource.t()]} | {:error, term()}
  def queue_details(base_url, api_key, series_id) when is_integer(series_id) do
    case Client.get(base_url, api_key, "/api/v3/queue/details", params: %{seriesId: series_id}) do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &QueueResource.from_api/1)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @spec queue_details!(String.t(), String.t(), integer()) :: list(QueueResource.t())
  def queue_details!(base_url, api_key, series_id) do
    {:ok, queue} = queue_details(base_url, api_key, series_id)
    queue
  end
end
