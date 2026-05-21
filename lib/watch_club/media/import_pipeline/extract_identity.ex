defmodule WatchClub.Media.ImportPipeline.ExtractIdentity do
  @moduledoc false

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.ContentHints
  alias WatchClub.Media.ImportConfiguration

  @external_attribute_regex ~r/[\[\(\{]\s*(tmdbid|tmdb|imdbid|imdb|tvdbid|tvdb)\s*[=-]\s*([^\]\)\}]+?)\s*[\]\)\}]/i
  @imdb_regex ~r/tt\d{7,8}/i
  @quality_token_regex ~r/\b(480p|576p|720p|1080p|2160p|4320p|bluray|blu-ray|bdrip|brrip|web-dl|webdl|webrip|hdtv|dvdrip|x264|x265|h264|h265|hevc|avc|proper|repack|limited|unrated|extended|remux)\b/i

  def apply(%Candidate{} = candidate, %ImportConfiguration{} = configuration) do
    external_ids =
      candidate.path
      |> external_ids_from_text()
      |> Map.merge(external_ids_from_nfo(candidate, configuration))

    hints =
      case configuration.content_type do
        :movie -> movie_hints(candidate, external_ids)
        :tv_show -> tv_show_hints(candidate, configuration, external_ids)
        :book -> book_hints(candidate, external_ids)
      end

    %{candidate | content_hints: hints}
  end

  defp movie_hints(candidate, external_ids) do
    {title, year} = title_and_year(candidate.path)

    %ContentHints{
      title: title,
      year: year,
      external_ids: external_ids,
      sources: sources(external_ids, title)
    }
  end

  defp tv_show_hints(candidate, configuration, external_ids) do
    episode = parse_episode(candidate.path)

    tv_show_title =
      episode[:tv_show_title] ||
        tv_show_title_from_path(candidate.path, configuration.filesystem_path)

    %ContentHints{
      tv_show_title: clean_title(tv_show_title),
      season_number: episode[:season_number],
      episode_number: episode[:episode_number],
      episode_title: clean_title(episode[:episode_title]),
      external_ids: external_ids,
      sources: sources(external_ids, episode[:episode_number])
    }
  end

  defp book_hints(candidate, external_ids) do
    {title, year} = title_and_year(candidate.path)

    %ContentHints{
      title: title,
      book_title: title,
      year: year,
      external_ids: external_ids,
      sources: sources(external_ids, title)
    }
  end

  defp external_ids_from_nfo(candidate, configuration) do
    candidate
    |> nfo_paths(configuration)
    |> Enum.reduce(%{}, fn path, external_ids ->
      case File.read(path) do
        {:ok, text} -> Map.merge(external_ids, external_ids_from_text(text))
        {:error, _reason} -> external_ids
      end
    end)
  end

  defp nfo_paths(candidate, configuration) do
    sidecar = candidate.path |> Path.rootname() |> Kernel.<>(".nfo")
    parent = Path.dirname(candidate.path)

    candidates =
      case configuration.content_type do
        :movie -> [sidecar, Path.join(parent, "movie.nfo")]
        :tv_show -> [sidecar] ++ tv_show_nfo_paths(parent, configuration.filesystem_path)
        :book -> [sidecar]
      end

    candidates
    |> Enum.uniq()
    |> Enum.filter(&regular_file?/1)
  end

  defp tv_show_nfo_paths(path, root_path) do
    path
    |> ancestors_until(root_path)
    |> Enum.flat_map(fn ancestor ->
      [Path.join(ancestor, "tvshow.nfo"), Path.join(ancestor, "season.nfo")]
    end)
  end

  defp ancestors_until(path, root_path) do
    expanded_root = Path.expand(root_path)

    path
    |> Path.expand()
    |> Stream.iterate(&Path.dirname/1)
    |> Enum.reduce_while([], fn current, ancestors ->
      cond do
        current == Path.dirname(current) ->
          {:halt, ancestors}

        current == expanded_root ->
          {:halt, [current | ancestors]}

        String.starts_with?(current, expanded_root) ->
          {:cont, [current | ancestors]}

        true ->
          {:halt, ancestors}
      end
    end)
  end

  defp regular_file?(path) do
    case File.lstat(path) do
      {:ok, %{type: :regular}} -> true
      _ -> false
    end
  end

  defp external_ids_from_text(text) do
    text
    |> external_ids_from_attributes()
    |> Map.merge(external_ids_from_xml_tags(text))
    |> Map.merge(external_ids_from_urls(text))
  end

  defp external_ids_from_attributes(text) do
    @external_attribute_regex
    |> Regex.scan(text)
    |> Enum.reduce(%{}, fn [_match, external, value], external_ids ->
      put_external_id(external_ids, external, String.trim(value))
    end)
    |> put_imdb_id_from_text(text)
  end

  defp external_ids_from_xml_tags(text) do
    %{}
    |> put_xml_tag(text, :tmdb, ~r/<tmdbid>\s*([^<]+)\s*<\/tmdbid>/i)
    |> put_xml_tag(text, :imdb, ~r/<imdbid>\s*([^<]+)\s*<\/imdbid>/i)
    |> put_xml_tag(text, :tvdb, ~r/<tvdbid>\s*([^<]+)\s*<\/tvdbid>/i)
    |> put_unique_id(text, :tmdb)
    |> put_unique_id(text, :imdb)
    |> put_unique_id(text, :tvdb)
  end

  defp external_ids_from_urls(text) do
    %{}
    |> put_regex_capture(:tmdb, text, ~r/themoviedb\.org\/(?:movie|tv)\/(\d+)/i)
    |> put_regex_capture(:tvdb, text, ~r/thetvdb\.com\/.*?[?&]id=(\d+)/i)
    |> put_imdb_id_from_text(text)
  end

  defp put_xml_tag(external_ids, text, external, regex) do
    put_regex_capture(external_ids, external, text, regex)
  end

  defp put_unique_id(external_ids, text, external) do
    regex = ~r/<uniqueid[^>]+type=["']#{external}["'][^>]*>\s*([^<]+)\s*<\/uniqueid>/i
    put_regex_capture(external_ids, external, text, regex)
  end

  defp put_regex_capture(external_ids, external, text, regex) do
    case Regex.run(regex, text) do
      [_match, value] -> Map.put(external_ids, external, String.trim(value))
      _ -> external_ids
    end
  end

  defp put_imdb_id_from_text(external_ids, text) do
    case Regex.run(@imdb_regex, text) do
      [imdb_id] -> Map.put_new(external_ids, :imdb, String.downcase(imdb_id))
      _ -> external_ids
    end
  end

  defp put_external_id(external_ids, external, value) do
    external = external |> String.downcase() |> normalize_external()
    Map.put(external_ids, external, value)
  end

  defp normalize_external(external) when external in ["tmdb", "tmdbid"], do: :tmdb
  defp normalize_external(external) when external in ["imdb", "imdbid"], do: :imdb
  defp normalize_external(external) when external in ["tvdb", "tvdbid"], do: :tvdb

  defp title_and_year(path) do
    stem = path |> Path.basename(Path.extname(path)) |> remove_external_attributes()
    year = parse_year(stem)
    title = stem |> remove_year(year) |> clean_title()

    {title, year}
  end

  defp parse_year(text) do
    case Regex.run(~r/(?:^|[^\d])((?:19|20)\d{2})(?:[^\d]|$)/, text) do
      [_match, year] -> String.to_integer(year)
      _ -> nil
    end
  end

  defp remove_year(text, nil), do: text
  defp remove_year(text, year), do: Regex.replace(~r/(?:^|[^\d])#{year}(?:[^\d]|$)/, text, " ")

  defp remove_external_attributes(text) do
    Regex.replace(~r/[\[\(\{][^\]\)\}]+[\]\)\}]/, text, " ")
  end

  defp parse_episode(path) do
    stem = path |> Path.basename(Path.extname(path)) |> remove_external_attributes()

    cond do
      match = Regex.run(~r/^(.*?)[\s._-]+S(\d{1,3})[\s._-]*E(\d{1,3})(?:[\s._-]+(.+))?$/i, stem) ->
        [_full, tv_show_title, season, episode | rest] = match

        %{
          tv_show_title: tv_show_title,
          season_number: String.to_integer(season),
          episode_number: String.to_integer(episode),
          episode_title: List.first(rest)
        }

      match = Regex.run(~r/^(.*?)[\s._-]+(\d{1,3})x(\d{1,3})(?:[\s._-]+(.+))?$/i, stem) ->
        [_full, tv_show_title, season, episode | rest] = match

        %{
          tv_show_title: tv_show_title,
          season_number: String.to_integer(season),
          episode_number: String.to_integer(episode),
          episode_title: List.first(rest)
        }

      true ->
        %{}
    end
  end

  defp tv_show_title_from_path(path, root_path) do
    path
    |> Path.dirname()
    |> tv_show_directory(root_path)
    |> Path.basename()
  end

  defp tv_show_directory(directory, root_path) do
    parent = Path.dirname(directory)

    if season_directory?(Path.basename(directory)) and parent != directory and
         String.starts_with?(Path.expand(parent), Path.expand(root_path)) do
      parent
    else
      directory
    end
  end

  defp season_directory?(name) do
    Regex.match?(~r/^(season\s*)?\d{1,3}$/i, name) or Regex.match?(~r/^s\d{1,3}$/i, name)
  end

  defp clean_title(nil), do: nil

  defp clean_title(text) do
    text
    |> String.replace(@quality_token_regex, " ")
    |> String.replace([".", "_"], " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim(" -")
    |> empty_to_nil()
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp sources(external_ids, parsed_value) do
    []
    |> maybe_add_source(:external_id, map_size(external_ids) > 0)
    |> maybe_add_source(:path, not is_nil(parsed_value))
  end

  defp maybe_add_source(sources, source, true), do: [source | sources]
  defp maybe_add_source(sources, _source, false), do: sources
end
