defmodule WatchClub.MediaSources.Import.Scanner.Radarr do
  @moduledoc """
  Radarr implementation of `WatchClub.MediaSources.Import.Scanner`.

  `scan/1` lists the Radarr catalog (`/api/v3/movie`), keeps movies with a
  downloaded file matching this Media Source's root folder and quality
  profile, and emits one `Candidate` per movie — identity from Radarr, and
  `path` mapped onto WatchClub's disk. Ingestion still probes with `ffprobe`:
  Radarr's `mediaInfo` lacks the per-stream detail the Player needs.
  """
  @behaviour WatchClub.MediaSources.Import.Scanner

  alias WatchClub.Integrations.Radarr
  alias WatchClub.Integrations.Radarr.Movie
  alias WatchClub.MediaSources.{Import, Servarr}
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.MovieIdentity
  alias WatchClub.Shared.Path, as: Paths

  require Logger

  @impl true
  def scan(%Import{
        media_source: %{implementation: %Servarr{flavor: :radarr} = config}
      }) do
    Logger.info("Fetch movies from Radarr", event: :radarr_fetch_started)

    config.base_url
    |> Radarr.list_movies!(config.api_key)
    |> tap(
      &Logger.info("#{length(&1)} movies fetched from Radarr",
        event: :radarr_fetch_success,
        num_movies: length(&1)
      )
    )
    |> Enum.filter(&belongs_to_source?(&1, config))
    |> Enum.map(&to_candidate(&1, config))
    |> tap(fn
      [] ->
        Logger.info("No eligible movies found", event: :radarr_scan_finished, num_candidates: 0)

      candidates ->
        num_candidates = length(candidates)

        Logger.info("Found #{num_candidates} eligible movies",
          event: :radarr_scan_finished,
          num_candidates: num_candidates
        )
    end)
  end

  defp belongs_to_source?(%Movie{} = movie, %Servarr{} = config) do
    movie.has_file? and
      is_binary(movie.file_path) and
      movie.quality_profile_id == config.quality_profile_id and
      Paths.normalize(movie.root_folder_path) == Paths.normalize(config.root_folder_path)
  end

  defp to_candidate(%Movie{} = movie, %Servarr{
         root_folder_path: root,
         local_root_folder_path: local_root
       }) do
    %Candidate{
      path: Paths.remap_prefix(movie.file_path, root, local_root),
      media_type: :movie,
      identity: %MovieIdentity{
        tmdb_id: movie.tmdb_id,
        imdb_id: movie.imdb_id,
        title: movie.title,
        year: movie.year
      }
    }
  end
end
