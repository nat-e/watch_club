defmodule WatchClub.Integrations.Sonarr do
  @moduledoc """
  Sonarr v3 API facade. Owns Sonarr's catalog endpoints (`/api/v3/series`
  plus per-series `/api/v3/episode`) and their response parsing. Every
  other endpoint is flavor-agnostic and lives on `Servarr.Client`.
  """

  alias WatchClub.Integrations.Servarr.Client
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
end
