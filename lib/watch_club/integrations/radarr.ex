defmodule WatchClub.Integrations.Radarr do
  @moduledoc """
  Radarr v3 API facade. Owns Radarr's catalog endpoint (`/api/v3/movie`)
  and its response parsing. Every other endpoint is flavor-agnostic and
  lives on `Servarr.Client`.
  """

  alias WatchClub.Integrations.Radarr.Movie
  alias WatchClub.Integrations.Servarr.Client

  @doc """
  Returns every movie in the Radarr library (no server-side filtering or
  pagination; callers filter client-side). Retries transient errors.
  """
  @spec list_movies(String.t(), String.t()) :: {:ok, [Movie.t()]} | {:error, term()}
  def list_movies(base_url, api_key) do
    case Client.get(base_url, api_key, "/api/v3/movie", retry: :transient) do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &Movie.from_api/1)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end
end
