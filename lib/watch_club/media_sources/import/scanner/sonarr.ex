defmodule WatchClub.MediaSources.Import.Scanner.Sonarr do
  @moduledoc """
  Sonarr implementation of `WatchClub.MediaSources.Import.Scanner`.

  `scan/1` lists the Sonarr catalog (`/api/v3/series`), keeps series under
  this Media Source's root folder and quality profile, then for each such
  series enumerates its episodes (`/api/v3/episode?seriesId=…`) and emits
  one `Candidate` per episode that has a downloaded file — identity from
  Sonarr (series external ids + season/episode numbers), and `path` mapped
  onto WatchClub's disk. The scan is where Sonarr diverges from Radarr
  (movie = one candidate, series = one candidate per episode file);
  ingestion is identical.
  """
  @behaviour WatchClub.MediaSources.Import.Scanner

  alias WatchClub.Integrations.Sonarr
  alias WatchClub.Integrations.Sonarr.{Episode, Series}
  alias WatchClub.MediaSources.{Import, Servarr}
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.EpisodeIdentity
  alias WatchClub.Shared.Path, as: Paths

  require Logger

  @impl true
  def scan(%Import{
        media_source: %{implementation: %Servarr{flavor: :sonarr} = config}
      }) do
    Logger.info("Fetch series from Sonarr", event: :sonarr_fetch_started)

    config.base_url
    |> Sonarr.list_series!(config.api_key)
    |> tap(
      &Logger.info("#{length(&1)} Series fetched from Sonarr",
        event: :sonarr_fetch_success,
        num_series: length(&1)
      )
    )
    |> Enum.filter(&belongs_to_source?(&1, config))
    |> Enum.flat_map(&series_candidates(&1, config))
    |> tap(fn
      [] ->
        Logger.info("No eligible Series found", event: :sonarr_scan_finished, num_candidates: 0)

      candidates ->
        num_candidates = length(candidates)

        Logger.info("Found #{num_candidates} eligible episodes",
          event: :sonarr_scan_finished,
          num_candidates: num_candidates
        )
    end)
  end

  defp belongs_to_source?(%Series{} = series, %Servarr{} = config) do
    series.quality_profile_id == config.quality_profile_id and
      is_binary(series.root_folder_path) and
      Paths.normalize(series.root_folder_path) == Paths.normalize(config.root_folder_path)
  end

  # List all the episodes for this Series.
  # Handle errors if this fails since we want to continue with the other imports
  defp series_candidates(%Series{} = series, %Servarr{} = config) do
    case Sonarr.list_episodes(config.base_url, config.api_key, series.id) do
      {:ok, episodes} ->
        episodes
        |> Enum.filter(&downloaded?/1)
        |> Enum.map(&to_candidate(&1, series, config))

      {:error, reason} ->
        Logger.warning("Error listing episodes for: #{series.title}",
          event: :sonarr_list_episodes_error,
          series_id: series.id,
          title: series.title,
          reason: reason
        )

        []
    end
  end

  defp downloaded?(%Episode{has_file?: true, file_path: path}) when is_binary(path), do: true
  defp downloaded?(%Episode{}), do: false

  defp to_candidate(
         %Episode{} = episode,
         %Series{} = series,
         %Servarr{root_folder_path: root, local_root_folder_path: local_root}
       ) do
    %Candidate{
      path: Paths.remap_prefix(episode.file_path, root, local_root),
      media_type: :tv_show_episode,
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
end
