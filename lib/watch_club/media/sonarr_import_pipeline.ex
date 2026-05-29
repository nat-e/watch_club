defmodule WatchClub.Media.SonarrImportPipeline do
  @moduledoc """
  Sonarr implementation of `WatchClub.Media.ImportPipeline`.

  `scan/1` lists the Sonarr catalog (`/api/v3/series`), keeps series under
  this Media Source's root folder and quality profile, then for each such
  series enumerates its episodes (`/api/v3/episode?seriesId=…`) and emits
  one `Candidate` per episode that has a downloaded file — identity from
  Sonarr (series external ids + season/episode numbers), and `path` mapped
  onto WatchClub's disk.

  `process_candidate/2` runs `ExtractStructure → MatchContent → SaveMedia`,
  identical to Radarr; the scan is where the two flavors diverge (movie =
  one candidate, series = one candidate per episode file).
  """
  @behaviour WatchClub.Media.ImportPipeline

  alias WatchClub.Integrations.Sonarr
  alias WatchClub.Integrations.Sonarr.{Episode, Series}
  alias WatchClub.Media.ImportPipeline.{Candidate, ExtractStructure, MatchContent, SaveMedia}
  alias WatchClub.Media.ImportPipeline.Candidate.EpisodeIdentity
  alias WatchClub.Media.{MediaImport, ServarrMediaSource}
  alias WatchClub.Shared.Path, as: Paths

  require Logger

  @impl true
  def scan(%MediaImport{
        media_source: %{implementation: %ServarrMediaSource{flavor: :sonarr} = config}
      }) do
    case Sonarr.list_series(config.base_url, config.api_key) do
      {:ok, series} ->
        candidates =
          series
          |> Enum.filter(&belongs_to_source?(&1, config))
          |> Enum.flat_map(&series_candidates(&1, config))

        Logger.info("Sonarr scan matched #{length(candidates)} episode file(s)")
        {:ok, candidates}

      {:error, reason} ->
        {:error, "Sonarr scan failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def process_candidate(%Candidate{} = candidate, %MediaImport{} = media_import) do
    Logger.info("Processing Sonarr import candidate: #{candidate}")

    with {:ok, candidate} <- ExtractStructure.apply(candidate, media_import),
         {:ok, candidate} <- MatchContent.apply(candidate, media_import),
         {:ok, candidate} <- SaveMedia.apply(candidate, media_import) do
      Logger.info("Finished processing candidate: #{candidate}")
      :ok
    end
  end

  defp belongs_to_source?(%Series{} = series, %ServarrMediaSource{} = config) do
    series.quality_profile_id == config.quality_profile_id and
      is_binary(series.root_folder_path) and
      Paths.normalize(series.root_folder_path) == Paths.normalize(config.root_folder_path)
  end

  defp series_candidates(%Series{} = series, %ServarrMediaSource{} = config) do
    case Sonarr.list_episodes(config.base_url, config.api_key, series.id) do
      {:ok, episodes} ->
        episodes
        |> Enum.filter(&downloaded?/1)
        |> Enum.map(&to_candidate(&1, series, config))

      {:error, reason} ->
        Logger.warning(
          "Sonarr episode list failed for series #{series.id} (#{series.title}): #{inspect(reason)}"
        )

        []
    end
  end

  defp downloaded?(%Episode{has_file?: true, file_path: path}) when is_binary(path), do: true
  defp downloaded?(%Episode{}), do: false

  defp to_candidate(%Episode{} = episode, %Series{} = series, %ServarrMediaSource{} = config) do
    %Candidate{
      path: local_path(episode.file_path, config),
      identity: %EpisodeIdentity{
        tvdb_id: series.tvdb_id,
        tmdb_id: series.tmdb_id,
        imdb_id: series.imdb_id,
        title: series.title,
        season_number: episode.season_number,
        episode_number: episode.episode_number
      }
    }
  end

  # Maps the Sonarr-side file path onto WatchClub's disk.
  defp local_path(file_path, %ServarrMediaSource{
         root_folder_path: root,
         local_root_folder_path: local_root
       }) do
    Paths.remap_prefix(file_path, root, local_root)
  end
end
