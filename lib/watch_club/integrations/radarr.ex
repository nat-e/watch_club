defmodule WatchClub.Integrations.Radarr do
  @moduledoc """
  Radarr v3 API client.
  """

  alias WatchClub.Integrations.Radarr.{Movie, QueueResource}
  alias WatchClub.Integrations.Servarr.Client

  @doc """
  Returns every movie in the Radarr library (no server-side filtering or
  pagination; callers filter client-side).
  """
  @spec list_movies(String.t(), String.t()) :: {:ok, list(Movie.t())} | {:error, Client.error()}
  def list_movies(base_url, api_key) do
    case Client.get(base_url, api_key, "/api/v3/movie") do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &Movie.from_api/1)}
      {:error, _} = error -> error
    end
  end

  @spec list_movies!(String.t(), String.t()) :: list(Movie.t())
  def list_movies!(base_url, api_key) do
    {:ok, movies} = list_movies(base_url, api_key)
    movies
  end

  @doc """
  Returns the `Movie` for `tmdb_id` if Radarr already has it, else `nil`. Used
  to adopt a movie rather than re-adding it.
  """
  @spec get_movie(String.t(), String.t(), integer()) ::
          {:ok, Movie.t() | nil} | {:error, Client.error()}
  def get_movie(base_url, api_key, tmdb_id) when is_integer(tmdb_id) do
    case Client.get(base_url, api_key, "/api/v3/movie", params: %{tmdbId: tmdb_id}) do
      {:ok, [movie | _]} when is_map(movie) -> {:ok, Movie.from_api(movie)}
      {:ok, []} -> {:ok, nil}
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
          {:ok, Movie.t()} | {:error, Client.error()}
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
      {:error, _} = error -> error
    end
  end

  @doc """
  Fetches one `Movie` by its Radarr id.
  `{:error, :not_found}` when the movie is no longer in the library.
  """
  @spec get_movie_by_id(String.t(), String.t(), integer()) ::
          {:ok, Movie.t()} | {:error, Client.error()}
  def get_movie_by_id(base_url, api_key, movie_id) when is_integer(movie_id) do
    case Client.get(base_url, api_key, "/api/v3/movie/#{movie_id}") do
      {:ok, movie} when is_map(movie) -> {:ok, Movie.from_api(movie)}
      {:error, _} = error -> error
    end
  end

  @spec get_movie_by_id!(String.t(), String.t(), integer()) :: Movie.t()
  def get_movie_by_id!(base_url, api_key, movie_id) do
    {:ok, movie} = get_movie_by_id(base_url, api_key, movie_id)
    movie
  end

  @doc """
  Returns the download-queue `QueueResource`s for one movie.
  """
  @spec queue_details(String.t(), String.t(), integer()) ::
          {:ok, [QueueResource.t()]} | {:error, Client.error()}
  def queue_details(base_url, api_key, movie_id) when is_integer(movie_id) do
    case Client.get(base_url, api_key, "/api/v3/queue/details", params: %{movieId: movie_id}) do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &QueueResource.from_api/1)}
      {:error, _} = error -> error
    end
  end

  @spec queue_details!(String.t(), String.t(), integer()) :: list(QueueResource.t())
  def queue_details!(base_url, api_key, movie_id) when is_integer(movie_id) do
    {:ok, queue} = queue_details(base_url, api_key, movie_id)
    queue
  end
end
