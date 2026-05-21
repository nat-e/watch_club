defmodule WatchClub.Media.ImportPipeline.ExtractIdentity.NfoParser do
  @moduledoc """
  Locates and parses Kodi/Jellyfin-style NFO sidecar files for a candidate.

  Port of `MediaBrowser.XbmcMetadata.{Providers,Parsers}`. Each entry point
  collapses Jellyfin's per-content-type `BaseNfoProvider<T>` + `BaseNfoParser<T>`
  pair into one function: locate the NFO paths (Jellyfin: `GetXmlFile`), read
  each that exists, walk the XML tags (Jellyfin: `FetchDataFromXmlNode`), and
  merge the per-file results in path order.

  NFO conventions reproduced:

    * Movies: `<basename>.nfo` next to the file, plus `movie.nfo` in the same
      directory. Both parsed with the `<movie>` schema.
    * TV episodes: `<basename>.nfo` next to the episode file (`<episodedetails>`
      schema), plus `tvshow.nfo` in any ancestor directory up to the import
      root (`<tvshow>` schema). `season.nfo` is located but its contents are
      currently discarded — we have no Season entity to populate.
    * Books: `<basename>.nfo` next to the file. `<book>` schema.

  Per-file results are merged left-to-right in the locator's order (sidecar
  first), with later values filling only what's still `nil`. Show-level fields
  from `tvshow.nfo` are namespaced (`show_title`, `show_year`,
  `show_external_ids`) on the `EpisodeResult` so the consumer can keep the
  episode-vs-show distinction.
  """

  require Record

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.ExternalIds
  alias WatchClub.Media.ImportPipeline.ExtractIdentity.ExternalIdExtractor

  defmodule MovieResult do
    @moduledoc false
    defstruct title: nil,
              original_title: nil,
              year: nil,
              premiered: nil,
              plot: nil,
              runtime_minutes: nil,
              tagline: nil,
              set_name: nil,
              genres: [],
              studios: [],
              countries: [],
              external_ids: %ExternalIds{}
  end

  defmodule EpisodeResult do
    @moduledoc false
    defstruct episode_title: nil,
              season_number: nil,
              episode_number: nil,
              aired: nil,
              plot: nil,
              runtime_minutes: nil,
              show_title: nil,
              show_year: nil,
              show_genres: [],
              external_ids: %ExternalIds{},
              show_external_ids: %ExternalIds{}
  end

  defmodule BookResult do
    @moduledoc false
    defstruct title: nil,
              year: nil,
              author: nil,
              isbn: nil,
              external_ids: %ExternalIds{}
  end

  # ----------------------------------------------------------------------
  # Public API — one entry point per content type, mirroring Jellyfin's
  # per-type Provider/Parser pairs.

  @doc """
  Parses NFO files for a movie candidate. Reads `<basename>.nfo` and
  `movie.nfo` in the candidate's directory.
  """
  @spec parse_movie(Candidate.t(), map()) :: MovieResult.t()
  def parse_movie(%Candidate{} = candidate, _configuration) do
    candidate
    |> movie_nfo_paths()
    |> read_and_merge(&parse_movie_xml/1, %MovieResult{})
  end

  @doc """
  Parses NFO files for a TV episode candidate. Reads the episode sidecar,
  then walks up to the import root collecting `tvshow.nfo`. Per Jellyfin's
  separation between `EpisodeNfoProvider` and `SeriesNfoProvider`, episode
  fields and show fields are kept distinct on the returned struct.
  """
  @spec parse_episode(Candidate.t(), map()) :: EpisodeResult.t()
  def parse_episode(%Candidate{} = candidate, configuration) do
    episode = read_and_merge(episode_nfo_paths(candidate), &parse_episode_xml/1, %EpisodeResult{})

    show =
      read_and_merge(
        tvshow_nfo_paths(candidate, configuration.filesystem_path),
        &parse_series_xml/1,
        %{}
      )

    merge_show_into_episode(episode, show)
  end

  @doc """
  Parses NFO file for a book candidate. Reads `<basename>.nfo` next to the
  file. No `book.nfo` directory-level convention exists in Jellyfin.
  """
  @spec parse_book(Candidate.t(), map()) :: BookResult.t()
  def parse_book(%Candidate{} = candidate, _configuration) do
    candidate
    |> book_nfo_paths()
    |> read_and_merge(&parse_book_xml/1, %BookResult{})
  end

  # ----------------------------------------------------------------------
  # Locator — port of `GetXmlFile` per provider type.

  defp movie_nfo_paths(%Candidate{path: path}) do
    [sidecar_path(path), Path.join(Path.dirname(path), "movie.nfo")]
    |> Enum.uniq()
    |> Enum.filter(&regular_file?/1)
  end

  defp episode_nfo_paths(%Candidate{path: path}) do
    [sidecar_path(path)] |> Enum.filter(&regular_file?/1)
  end

  defp tvshow_nfo_paths(%Candidate{path: path}, root_path) do
    Path.dirname(path)
    |> ancestors_until(root_path)
    |> Enum.map(&Path.join(&1, "tvshow.nfo"))
    |> Enum.uniq()
    |> Enum.filter(&regular_file?/1)
  end

  defp book_nfo_paths(%Candidate{path: path}) do
    [sidecar_path(path)] |> Enum.filter(&regular_file?/1)
  end

  defp sidecar_path(path), do: Path.rootname(path) <> ".nfo"

  # Returns ancestors deepest-first (so callers reading NFOs in order have the
  # most-specific directory's `tvshow.nfo` win the merge).
  defp ancestors_until(starting_dir, root_path) do
    expanded_root = Path.expand(root_path)

    starting_dir
    |> Path.expand()
    |> Stream.iterate(&Path.dirname/1)
    |> Enum.reduce_while([], fn current, acc ->
      cond do
        current == expanded_root -> {:halt, [current | acc]}
        current == Path.dirname(current) -> {:halt, acc}
        String.starts_with?(current, expanded_root <> "/") -> {:cont, [current | acc]}
        true -> {:halt, acc}
      end
    end)
    |> Enum.reverse()
  end

  defp regular_file?(path) do
    case File.lstat(path) do
      {:ok, %{type: :regular}} -> true
      _ -> false
    end
  end

  # ----------------------------------------------------------------------
  # Reader / merger — port of `BaseNfoParser.Fetch` loop.

  defp read_and_merge(paths, parser, initial) do
    paths
    |> Enum.reduce(initial, fn path, acc ->
      case File.read(path) do
        {:ok, xml} ->
          case parser.(xml) do
            nil -> acc
            parsed -> merge_left_wins(acc, parsed)
          end

        {:error, _} ->
          acc
      end
    end)
  end

  defp merge_left_wins(%struct{} = left, %struct{} = right) do
    Enum.reduce(Map.from_struct(right), left, fn {key, right_value}, acc ->
      case Map.get(acc, key) do
        nil -> Map.put(acc, key, right_value)
        [] -> Map.put(acc, key, right_value)
        %ExternalIds{} = current -> Map.put(acc, key, union_external_ids(current, right_value))
        _kept -> acc
      end
    end)
  end

  defp merge_left_wins(%_struct{} = left, map) when is_map(map), do: left

  defp merge_left_wins(map, %_struct{}) when is_map(map), do: map

  defp merge_left_wins(left, right) when is_map(left) and is_map(right) do
    Map.merge(right, left)
  end

  defp union_external_ids(%ExternalIds{} = left, %ExternalIds{} = right) do
    %ExternalIds{
      tmdb: left.tmdb || right.tmdb,
      imdb: left.imdb || right.imdb,
      tvdb: left.tvdb || right.tvdb
    }
  end

  defp union_external_ids(%ExternalIds{} = left, _), do: left

  defp merge_show_into_episode(%EpisodeResult{} = episode, show) when is_map(show) do
    %EpisodeResult{
      episode
      | show_title: episode.show_title || show[:title],
        show_year: episode.show_year || show[:year],
        show_genres:
          if(episode.show_genres == [], do: Map.get(show, :genres, []), else: episode.show_genres),
        show_external_ids:
          union_external_ids(
            episode.show_external_ids,
            Map.get(show, :external_ids, %ExternalIds{})
          )
    }
  end

  # ----------------------------------------------------------------------
  # Parsers — port of `BaseNfoParser.FetchDataFromXmlNode` per content type.
  # `:xmerl_scan` returns an Erlang record tree; we extract leaf text for the
  # tags we care about. External IDs go through the shared extractor so the
  # `<uniqueid>` / `<tmdbid>` / `<imdbid>` / `<tvdbid>` recognition matches
  # Jellyfin's `ParseProviderLinks` (which also reads from raw XML).
  # ----------------------------------------------------------------------

  # Parser per content type. When the body isn't well-formed XML for the
  # expected root, we still scan it for provider URLs/IDs — Jellyfin's
  # Radarr/Imdb/Tmdb/Tvdb URL-only NFO fixtures rely on this behavior.

  defp parse_movie_xml(xml) do
    case scan(xml, ~w(movie)) do
      {:ok, root} ->
        %MovieResult{
          title: text(root, "title"),
          original_title: text(root, "originaltitle"),
          year: int(root, "year") || year_from_date(text(root, "premiered")),
          premiered: date(root, "premiered"),
          plot: text(root, "plot"),
          runtime_minutes: int(root, "runtime"),
          tagline: text(root, "tagline"),
          set_name: nested_text(root, "set", "name") || text(root, "set"),
          genres: texts(root, "genre"),
          studios: texts(root, "studio"),
          countries: texts(root, "country"),
          external_ids: ExternalIdExtractor.from_text(xml)
        }

      :error ->
        %MovieResult{external_ids: ExternalIdExtractor.from_text(xml)}
    end
  end

  defp parse_episode_xml(xml) do
    case scan(xml, ~w(episodedetails)) do
      {:ok, root} ->
        %EpisodeResult{
          episode_title: text(root, "title"),
          season_number: int(root, "season"),
          episode_number: int(root, "episode"),
          aired: date(root, "aired"),
          plot: text(root, "plot"),
          runtime_minutes: int(root, "runtime"),
          show_title: text(root, "showtitle"),
          external_ids: ExternalIdExtractor.from_text(xml)
        }

      :error ->
        %EpisodeResult{external_ids: ExternalIdExtractor.from_text(xml)}
    end
  end

  defp parse_series_xml(xml) do
    case scan(xml, ~w(tvshow)) do
      {:ok, root} ->
        %{
          title: text(root, "title"),
          year: int(root, "year") || year_from_date(text(root, "premiered")),
          genres: texts(root, "genre"),
          external_ids: ExternalIdExtractor.from_text(xml)
        }

      :error ->
        %{external_ids: ExternalIdExtractor.from_text(xml)}
    end
  end

  defp parse_book_xml(xml) do
    case scan(xml, ~w(book)) do
      {:ok, root} ->
        %BookResult{
          title: text(root, "title"),
          year: int(root, "year"),
          author: text(root, "author"),
          isbn: text(root, "isbn"),
          external_ids: ExternalIdExtractor.from_text(xml)
        }

      :error ->
        %BookResult{external_ids: ExternalIdExtractor.from_text(xml)}
    end
  end

  # ----------------------------------------------------------------------
  # XML helpers built on :xmerl_scan (no extra dependency)

  # xmerl records — declared inline to avoid pulling :xmerl headers globally.
  Record.defrecordp(:xml_element, :xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl"))
  Record.defrecordp(:xml_text, :xmlText, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl"))

  defp scan(xml, allowed_roots) do
    try do
      {parsed, _rest} = :xmerl_scan.string(String.to_charlist(xml), quiet: true)
      tag = parsed |> xml_element(:name) |> Atom.to_string()
      if tag in allowed_roots, do: {:ok, parsed}, else: :error
    rescue
      _ -> :error
    catch
      :exit, _ -> :error
      _, _ -> :error
    end
  end

  defp text(element, tag_name) do
    element
    |> children(tag_name)
    |> List.first()
    |> element_text()
  end

  defp texts(element, tag_name) do
    element
    |> children(tag_name)
    |> Enum.map(&element_text/1)
    |> Enum.reject(&is_nil/1)
  end

  defp nested_text(element, parent_tag, child_tag) do
    element
    |> children(parent_tag)
    |> List.first()
    |> case do
      nil -> nil
      parent -> text(parent, child_tag)
    end
  end

  defp int(element, tag_name) do
    case text(element, tag_name) do
      nil ->
        nil

      value ->
        case Integer.parse(value) do
          {n, _} -> n
          :error -> nil
        end
    end
  end

  defp date(element, tag_name) do
    with value when is_binary(value) <- text(element, tag_name),
         {:ok, date} <- Date.from_iso8601(String.slice(value, 0, 10)) do
      date
    else
      _ -> nil
    end
  end

  defp year_from_date(nil), do: nil

  defp year_from_date(value) when is_binary(value) do
    case Date.from_iso8601(String.slice(value, 0, 10)) do
      {:ok, date} -> date.year
      _ -> nil
    end
  end

  defp children(element, tag_name) do
    target = String.to_atom(tag_name)

    element
    |> xml_element(:content)
    |> Enum.filter(fn
      node when elem(node, 0) == :xmlElement -> xml_element(node, :name) == target
      _ -> false
    end)
  end

  defp element_text(nil), do: nil

  defp element_text(element) do
    element
    |> xml_element(:content)
    |> Enum.map(fn
      node when elem(node, 0) == :xmlText -> node |> xml_text(:value) |> to_string()
      _ -> ""
    end)
    |> Enum.join()
    |> String.trim()
    |> case do
      "" -> nil
      value -> value
    end
  end
end
