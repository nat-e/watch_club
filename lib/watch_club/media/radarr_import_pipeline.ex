defmodule WatchClub.Media.RadarrImportPipeline do
  @moduledoc """
  Radarr implementation of `WatchClub.Media.ImportPipeline`.

  `scan/1` lists the Radarr catalog (`/api/v3/movie`), keeps movies with a
  downloaded file matching this Media Source's root folder and quality
  profile, and emits one `Candidate` per movie — identity from Radarr, and
  `path` mapped onto WatchClub's disk.

  `process_candidate/2` runs `ExtractStructure → MatchContent → SaveMedia`
  (identity is already set by scan). `ExtractStructure` still probes with
  `ffprobe`: Radarr's `mediaInfo` lacks the per-stream detail the Player
  needs.
  """
  @behaviour WatchClub.Media.ImportPipeline

  alias WatchClub.Integrations.Radarr
  alias WatchClub.Integrations.Radarr.Movie
  alias WatchClub.Media.ImportPipeline.{Candidate, ExtractStructure, MatchContent, SaveMedia}
  alias WatchClub.Media.ImportPipeline.Candidate.MovieIdentity
  alias WatchClub.Media.{MediaImport, ServarrMediaSource}
  alias WatchClub.Shared.Path, as: Paths

  require Logger

  @impl true
  def scan(%MediaImport{
        media_source: %{implementation: %ServarrMediaSource{flavor: :radarr} = config}
      }) do
    case Radarr.list_movies(config.base_url, config.api_key) do
      {:ok, movies} ->
        candidates =
          movies
          |> Enum.filter(&belongs_to_source?(&1, config))
          |> Enum.map(&to_candidate(&1, config))

        Logger.info("Radarr scan matched #{length(candidates)} movie file(s)")
        {:ok, candidates}

      {:error, reason} ->
        {:error, "Radarr scan failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def process_candidate(%Candidate{} = candidate, %MediaImport{} = media_import) do
    Logger.info("Processing Radarr import candidate: #{candidate}")

    with {:ok, candidate} <- ExtractStructure.apply(candidate, media_import),
         {:ok, candidate} <- MatchContent.apply(candidate, media_import),
         {:ok, candidate} <- SaveMedia.apply(candidate, media_import) do
      Logger.info("Finished processing candidate: #{candidate}")
      :ok
    end
  end

  defp belongs_to_source?(%Movie{} = movie, %ServarrMediaSource{} = config) do
    movie.has_file? and
      is_binary(movie.file_path) and
      movie.quality_profile_id == config.quality_profile_id and
      Paths.normalize(movie.root_folder_path) == Paths.normalize(config.root_folder_path)
  end

  defp to_candidate(%Movie{} = movie, %ServarrMediaSource{} = config) do
    %Candidate{
      path: local_path(movie.file_path, config),
      identity: %MovieIdentity{
        tmdb_id: movie.tmdb_id,
        imdb_id: movie.imdb_id,
        title: movie.title,
        year: movie.year
      }
    }
  end

  # Maps the Radarr-side file path onto WatchClub's disk.
  defp local_path(file_path, %ServarrMediaSource{
         root_folder_path: root,
         local_root_folder_path: local_root
       }) do
    Paths.remap_prefix(file_path, root, local_root)
  end
end
