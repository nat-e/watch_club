defmodule WatchClub.Integrations.Radarr do
  @moduledoc """
  Radarr v3 API facade. Owns Radarr's catalog endpoint (`/api/v3/movie`)
  and its response parsing. Every other endpoint is flavor-agnostic and
  lives on `Servarr.Client`.
  """

  alias WatchClub.Integrations.Radarr.Movie
  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.Integrations.Servarr.QueueItem

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

  @doc """
  Returns the `Movie` for `tmdb_id` if Radarr already has it, else `nil`. Used
  to adopt a movie rather than re-adding it.
  """
  @spec get_movie(String.t(), String.t(), integer()) :: {:ok, Movie.t() | nil} | {:error, term()}
  def get_movie(base_url, api_key, tmdb_id) when is_integer(tmdb_id) do
    case Client.get(base_url, api_key, "/api/v3/movie?tmdbId=#{tmdb_id}", retry: :transient) do
      {:ok, [movie | _]} when is_map(movie) -> {:ok, Movie.from_api(movie)}
      {:ok, []} -> {:ok, nil}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @doc """
  Adds a movie to Radarr — monitored, on the given quality profile + root
  folder — and triggers a search. No lookup needed: Radarr fills the rest of
  the movie metadata from `tmdb_id`, so only the title is sent alongside it.
  Returns the created `Movie`.
  """
  @spec add_movie(String.t(), String.t(), integer(), String.t(), integer(), String.t()) ::
          {:ok, Movie.t()} | {:error, term()}
  def add_movie(base_url, api_key, tmdb_id, title, quality_profile_id, root_folder_path) do
    body = %{
      "tmdbId" => tmdb_id,
      "title" => title,
      "qualityProfileId" => quality_profile_id,
      "rootFolderPath" => root_folder_path,
      "monitored" => true,
      "addOptions" => %{"searchForMovie" => true, "monitor" => "movieOnly"}
    }

    case Client.post(base_url, api_key, "/api/v3/movie", body) do
      {:ok, %{"id" => _} = movie} -> {:ok, Movie.from_api(movie)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @doc """
  Fetches one `Movie` by its Radarr id (`GET /api/v3/movie/{id}`).
  `{:error, :not_found}` when the movie is no longer in the library.
  """
  @spec get_movie_by_id(String.t(), String.t(), integer()) :: {:ok, Movie.t()} | {:error, term()}
  def get_movie_by_id(base_url, api_key, movie_id) when is_integer(movie_id) do
    case Client.get(base_url, api_key, "/api/v3/movie/#{movie_id}", retry: :transient) do
      {:ok, movie} when is_map(movie) -> {:ok, Movie.from_api(movie)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @doc """
  Returns the download-queue `QueueItem`s for one movie
  (`GET /api/v3/queue/details?movieId=`). An empty list means nothing is
  queued or downloading.
  """
  @spec queue_details(String.t(), String.t(), integer()) ::
          {:ok, [QueueItem.t()]} | {:error, term()}
  def queue_details(base_url, api_key, movie_id) when is_integer(movie_id) do
    case Client.get(base_url, api_key, "/api/v3/queue/details?movieId=#{movie_id}",
           retry: :transient
         ) do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &QueueItem.from_api/1)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end
end
