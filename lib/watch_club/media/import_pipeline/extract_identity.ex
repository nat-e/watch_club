defmodule WatchClub.Media.ImportPipeline.ExtractIdentity do
  @moduledoc """
  Populates `candidate.identity` with what the file claims to be.

  Orchestration only. Dispatches on `configuration.content_type`, runs the
  `FilenameParser` (what the path claims) and the matching `NfoParser` entry
  point (what the sidecar XML claims), then merges the two into the
  `Candidate.Identity` struct.

  Merge policy, mirroring Jellyfin's provider precedence (NFOs are authored
  intent, filenames are heuristics):

    * Scalar fields: the NFO value overwrites the filename value when present.
    * `external_ids`: unioned slot-by-slot (filename `[tmdb-123]` + NFO
      `<imdbid>tt456</imdbid>` both land).
    * `sources`: per-field map tracking which source (`:filename`,
      `:nfo_sidecar`, `:nfo_show`) filled each value.
  """

  @behaviour WatchClub.Media.ImportPipeline.Stage

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.{ExternalIds, Identity}
  alias WatchClub.Media.ImportPipeline.ExtractIdentity.{FilenameParser, NfoParser}
  alias WatchClub.Media.ImportPipeline.ExtractIdentity.ExternalIdExtractor
  alias WatchClub.Media.ImportPipeline.ExtractIdentity.NfoParser.{BookResult, EpisodeResult, MovieResult}
  alias WatchClub.Media.ImportRun

  @impl true
  def apply(%Candidate{} = candidate, %ImportRun{snapshot_configuration: configuration}) do
    identity =
      case configuration.content_type do
        :movie -> build_movie(candidate, configuration)
        :tv_show -> build_tv_show(candidate, configuration)
        :book -> build_book(candidate, configuration)
      end

    {:ok, %{candidate | identity: identity}}
  end

  # ----------------------------------------------------------------------
  # Per-content-type builders. Each one: start with the filename's claims,
  # then layer the NFO's claims on top.

  defp build_movie(candidate, configuration) do
    {title, year} = FilenameParser.title_and_year(candidate.path)
    path_ids = ExternalIdExtractor.from_text(candidate.path)

    base =
      %Identity{}
      |> overwrite(:title, title, :filename)
      |> overwrite(:year, year, :filename)
      |> union_external_ids(:external_ids, path_ids, :filename)

    apply_movie_nfo(base, NfoParser.parse_movie(candidate, configuration))
  end

  defp build_tv_show(candidate, configuration) do
    episode = FilenameParser.parse_episode(candidate.path)

    show_title =
      episode[:tv_show_title] ||
        FilenameParser.clean_title(
          FilenameParser.tv_show_title_from_path(candidate.path, configuration.filesystem_path)
        )

    path_ids = ExternalIdExtractor.from_text(candidate.path)
    show_path_ids = ExternalIdExtractor.from_text(Path.dirname(candidate.path))

    base =
      %Identity{}
      |> overwrite(:episode_title, episode[:episode_title], :filename)
      |> overwrite(:season_number, episode[:season_number], :filename)
      |> overwrite(:episode_number, episode[:episode_number], :filename)
      |> overwrite(:show_title, show_title, :filename)
      |> union_external_ids(:external_ids, path_ids, :filename)
      |> union_external_ids(:show_external_ids, show_path_ids, :filename)

    apply_episode_nfo(base, NfoParser.parse_episode(candidate, configuration))
  end

  defp build_book(candidate, configuration) do
    {title, year} = FilenameParser.title_and_year(candidate.path)
    path_ids = ExternalIdExtractor.from_text(candidate.path)

    base =
      %Identity{}
      |> overwrite(:title, title, :filename)
      |> overwrite(:year, year, :filename)
      |> union_external_ids(:external_ids, path_ids, :filename)

    apply_book_nfo(base, NfoParser.parse_book(candidate, configuration))
  end

  # ----------------------------------------------------------------------
  # NFO application. NFO wins for scalars; external IDs are unioned.

  defp apply_movie_nfo(identity, %MovieResult{} = nfo) do
    identity
    |> overwrite(:title, nfo.title, :nfo_sidecar)
    |> overwrite(:original_title, nfo.original_title, :nfo_sidecar)
    |> overwrite(:year, nfo.year, :nfo_sidecar)
    |> overwrite(:premiered, nfo.premiered, :nfo_sidecar)
    |> overwrite(:plot, nfo.plot, :nfo_sidecar)
    |> overwrite(:runtime_minutes, nfo.runtime_minutes, :nfo_sidecar)
    |> overwrite(:tagline, nfo.tagline, :nfo_sidecar)
    |> overwrite(:set_name, nfo.set_name, :nfo_sidecar)
    |> overwrite_list(:genres, nfo.genres, :nfo_sidecar)
    |> overwrite_list(:studios, nfo.studios, :nfo_sidecar)
    |> overwrite_list(:countries, nfo.countries, :nfo_sidecar)
    |> union_external_ids(:external_ids, nfo.external_ids, :nfo_sidecar)
  end

  defp apply_episode_nfo(identity, %EpisodeResult{} = nfo) do
    identity
    |> overwrite(:episode_title, nfo.episode_title, :nfo_sidecar)
    |> overwrite(:season_number, nfo.season_number, :nfo_sidecar)
    |> overwrite(:episode_number, nfo.episode_number, :nfo_sidecar)
    |> overwrite(:aired, nfo.aired, :nfo_sidecar)
    |> overwrite(:plot, nfo.plot, :nfo_sidecar)
    |> overwrite(:runtime_minutes, nfo.runtime_minutes, :nfo_sidecar)
    |> overwrite(:show_title, nfo.show_title, :nfo_show)
    |> overwrite(:show_year, nfo.show_year, :nfo_show)
    |> overwrite_list(:show_genres, nfo.show_genres, :nfo_show)
    |> union_external_ids(:external_ids, nfo.external_ids, :nfo_sidecar)
    |> union_external_ids(:show_external_ids, nfo.show_external_ids, :nfo_show)
  end

  defp apply_book_nfo(identity, %BookResult{} = nfo) do
    identity
    |> overwrite(:title, nfo.title, :nfo_sidecar)
    |> overwrite(:year, nfo.year, :nfo_sidecar)
    |> overwrite(:author, nfo.author, :nfo_sidecar)
    |> overwrite(:isbn, nfo.isbn, :nfo_sidecar)
    |> union_external_ids(:external_ids, nfo.external_ids, :nfo_sidecar)
  end

  # ----------------------------------------------------------------------
  # Merge helpers.

  defp overwrite(%Identity{} = identity, _key, nil, _source), do: identity

  defp overwrite(%Identity{} = identity, key, value, source) do
    identity
    |> Map.put(key, value)
    |> record_source(key, source)
  end

  defp overwrite_list(%Identity{} = identity, _key, [], _source), do: identity

  defp overwrite_list(%Identity{} = identity, key, values, source) when is_list(values) do
    identity
    |> Map.put(key, values)
    |> record_source(key, source)
  end

  defp union_external_ids(%Identity{} = identity, key, %ExternalIds{} = incoming, source) do
    current = Map.fetch!(identity, key)

    merged = %ExternalIds{
      tmdb: current.tmdb || incoming.tmdb,
      imdb: current.imdb || incoming.imdb,
      tvdb: current.tvdb || incoming.tvdb
    }

    identity = Map.put(identity, key, merged)

    if added_any?(current, incoming) do
      record_source(identity, key, source)
    else
      identity
    end
  end

  defp added_any?(%ExternalIds{} = current, %ExternalIds{} = incoming) do
    (is_nil(current.tmdb) and not is_nil(incoming.tmdb)) or
      (is_nil(current.imdb) and not is_nil(incoming.imdb)) or
      (is_nil(current.tvdb) and not is_nil(incoming.tvdb))
  end

  defp record_source(%Identity{sources: sources} = identity, key, source) do
    %{identity | sources: Map.put_new(sources, key, source)}
  end
end
