defmodule WatchClub.Media.ImportPipeline.ExtractIdentity.FilenameParser do
  @moduledoc """
  Extracts identity information from a candidate's path. Port of Jellyfin's
  `Emby.Naming` namespace — pure functions on strings, no I/O.

  The regex tables (`@episode_expressions`, `@clean_strings`,
  `@clean_date_times`, `@season_*`) are translated from
  `Emby.Naming/Common/NamingOptions.cs` and `Emby.Naming/TV/SeasonPathParser.cs`
  on the Jellyfin `master` branch. Patterns are tried in the order Jellyfin
  defines; the first match wins.
  """

  alias WatchClub.Shared.Path, as: Paths

  # ----------------------------------------------------------------------
  # Regex tables — direct port of Jellyfin NamingOptions.cs

  # CleanDateTimes — pulls (19xx | 20xx) year out of a stem.
  # NamingOptions.cs lines 147-151
  @clean_date_times [
    ~r/(.+[^_,.\(\)\[\]\-])[_.\(\)\[\]\-](19[0-9]{2}|20[0-9]{2})(?![0-9]+|\W[0-9]{2}\W[0-9]{2})([ _,.\(\)\[\]\-][^0-9]|).*(19[0-9]{2}|20[0-9]{2})*/,
    ~r/(.+[^_,.\(\)\[\]\-])[ _.\(\)\[\]\-]+(19[0-9]{2}|20[0-9]{2})(?![0-9]+|\W[0-9]{2}\W[0-9]{2})([ _,.\(\)\[\]\-][^0-9]|).*(19[0-9]{2}|20[0-9]{2})*/
  ]

  # CleanStrings — strip quality / release / bracket tokens.
  # NamingOptions.cs lines 153-161. All compiled case-insensitive.
  @clean_strings [
    ~r/^\s*(?<cleaned>.+?)[ _,.\(\)\[\]\-](3d|sbs|tab|hsbs|htab|mvc|HDR|HDC|UHD|UltraHD|4k|ac3|dts|custom|dc|divx|divx5|dsr|dsrip|dutch|dvd|dvdrip|dvdscr|dvdscreener|screener|dvdivx|cam|fragment|fs|hdtv|hdrip|hdtvrip|internal|limited|multi|subs|ntsc|ogg|ogm|pal|pdtv|proper|repack|rerip|retail|cd[1-9]|r5|bd5|bd|se|svcd|swedish|german|read.nfo|nfofix|unrated|ws|telesync|ts|telecine|tc|brrip|bdrip|480p|480i|576p|576i|720p|720i|1080p|1080i|2160p|hrhd|hrhdtv|hddvd|bluray|blu-ray|x264|x265|h264|h265|xvid|xvidvd|xxx|www.www|AAC|DTS)(?=[ _,.\(\)\[\]\-]|$)/i,
    ~r/^\s*(?<cleaned>.+?)((\s*\[[^\]]+\]\s*)+)(\.[^\s]+)?$/i,
    ~r/^\s*(?<cleaned>.+?)\WE[0-9]+(-|~)E?[0-9]+(\W|$)/i,
    ~r/^\s*\[[^\]]+\](?!\.\w+$)\s*(?<cleaned>.+)/i,
    ~r/^\s*(?<cleaned>.+?)\s+-\s+[0-9]+\s*$/i,
    ~r/^\s*(?<cleaned>.+?)(([-._ ](trailer|sample))|-(scene|clip|behindthescenes|deleted|deletedscene|featurette|short|interview|other|extra))$/i
  ]

  # EpisodeExpressions — port of the SxxExx / NxM / dated / anime patterns.
  # NamingOptions.cs lines 321-491. Slashes only (Jellyfin matches both `\` and
  # `/`); since we run on Unix and basename has already stripped separators
  # where appropriate, we keep the path-walking variants too.
  @episode_expressions [
    # 1. SxxExx with optional series-name capture (Kodi convention).
    ~r{.*/(?<seriesname>((?![Ss]([0-9]+)[][ ._-]*[Ee]([0-9]+))[^/])*)?[Ss](?<seasonnumber>[0-9]+)[][ ._-]*[Ee](?<epnumber>[0-9]+)([^/]*)$},
    # 2-3. Simple [Ee]pNN / [Ee]NN patterns.
    ~r/[._ -][Ee][Pp]_?(?<epnumber>[0-9]+)([^\/]*)$/,
    ~r/[^\/]*?\.?[Ee](?<epnumber>[0-9]+)\.([^\/]*)$/,
    # 4. Dated YYYY-MM-DD.
    ~r/(?<year>[0-9]{4})[._ -](?<month>[0-9]{2})[._ -](?<day>[0-9]{2})/,
    # 5. Dated DD-MM-YYYY.
    ~r/(?<day>[0-9]{2})[._ -](?<month>[0-9]{2})[._ -](?<year>[0-9]{4})/,
    # 6. "Series Season X Episode X".
    ~r/.*\/((?<seriesname>[^\/]+?)\s)?[Ss](?:eason)?\s*(?<seasonnumber>[0-9]+)\s+[Ee](?:pisode)?\s*(?<epnumber>[0-9]+).*$/,
    # 16-17. Series + NxM / SxxExx (preferred over bare NxM below — keeps
    # the seriesname capture when the path includes the show directory).
    ~r/.*\/(?<seriesname>((?![sS]?[0-9]{1,4}[xX][0-9]{1,3})[^\/])*)?(?:[sS]?(?<seasonnumber>[0-9]{1,4})[xX](?<epnumber>[0-9]+))[^\/]*$/,
    ~r/.*\/(?<seriesname>[^\/]*)[sS](?<seasonnumber>[0-9]{1,4})[xX.]?[eE](?<epnumber>[0-9]+)[^\/]*$/,
    # 8. Bare NxM (no series capture — last resort for non-path strings).
    ~r/[\/._ \[\(-](?<seasonnumber>[0-9]+)x(?<epnumber>[0-9]+(?:(?:[a-i]|\.[1-9])(?![0-9]))?)([^\/]*)$/,
    # 9. Anime `[group] Series - 01`.
    ~r/.*\/?.*?(\[.*?\])+.*?(?<seriesname>[-\w\s]+?)[\s_]*-[\s_]*(?<epnumber>[0-9]+).*$/,
    # 10. "Name - 101.mkv" anime absolute.
    ~r/.*\/(?<seriesname>[^\/]+?)[\s_]+-[\s_]+(?<epnumber>[0-9]+)[\s_]*(?:\[.*?\]|\(.*?\))*[\s_]*(?:\.\w+)?$/,
    # 13. "Episode 16".
    ~r/[Ee]pisode (?<epnumber>[0-9]+)(-(?<endingepnumber>[0-9]+))?[^\/]*$/i,
    # 14-15. Path-anchored S?NN x|e NN (kept as fallbacks).
    ~r/.*\/[sS]?(?<seasonnumber>[0-9]+)[xX](?<epnumber>[0-9]+)[^\/]*$/,
    ~r/.*\/[sS](?<seasonnumber>[0-9]+)[xX]?[eE](?<epnumber>[0-9]+)[^\/]*$/,
    # 26. Anime `[Group][Series][21]`.
    ~r/(?:\[(?:[^\]]+)\]\s*)?(?<seriesname>\[[^\]]+\]|[^\[\]]+)\s*\[(?<epnumber>[0-9]+)\]/
  ]

  # SeasonPathParser — Emby.Naming/TV/SeasonPathParser.cs
  @season_clean_chars ~r/[ ._\-\[\]]/
  @season_prefix_regex ~r/^[sS](?<seasonnumber>\d{1,4})(?!\d|[eE]\d)(?=\.|_|-|\[|\]|\s|$)/

  # ----------------------------------------------------------------------
  # Public API

  @doc """
  Returns `{title, year}` from the file's basename.

  Jellyfin recipe: take the basename without extension, run `CleanDateTimes` to
  separate title from year, then `CleanStrings` to strip quality/release
  tokens. Either component may be `nil` if nothing parseable is found.
  """
  @spec title_and_year(String.t()) :: {String.t() | nil, integer() | nil}
  def title_and_year(path) when is_binary(path) do
    stem = path |> Path.basename() |> drop_extension()
    {name_without_year, year} = clean_date_time(stem)
    title = clean_title(name_without_year)
    {title, year}
  end

  @doc """
  Parses season/episode information from the basename. Returns a map with
  `:tv_show_title`, `:season_number`, `:episode_number`, `:episode_title`
  when a pattern matches; otherwise an empty map.

  Jellyfin's `EpisodePathParser.Parse` runs the expression table top-to-bottom
  and returns on the first match. We mirror that. The `seriesname` capture (if
  any) becomes `:tv_show_title`; numeric captures become `:season_number` /
  `:episode_number`.
  """
  @spec parse_episode(String.t()) :: %{
          optional(:tv_show_title) => String.t(),
          optional(:season_number) => integer(),
          optional(:episode_number) => integer(),
          optional(:episode_title) => String.t()
        }
  def parse_episode(path) when is_binary(path) do
    # The expressions expect path-style separators; ensure we feed an absolute
    # form so the `.*/` anchors fire.
    candidate_path = ensure_leading_slash(path)

    @episode_expressions
    |> Enum.find_value(%{}, fn regex ->
      case Regex.named_captures(regex, candidate_path) do
        nil -> nil
        captures -> build_episode(captures, path)
      end
    end)
  end

  @doc """
  Infers the TV show's directory name from a candidate's path.

  Jellyfin's recipe (`SeriesResolver` + `SeasonPathParser`): if the immediate
  parent directory is a recognized season directory, the grandparent is the
  show's directory; otherwise the parent is. Walks up at most one level, never
  past `root_path`.
  """
  @spec tv_show_title_from_path(String.t(), String.t()) :: String.t()
  def tv_show_title_from_path(path, root_path) when is_binary(path) and is_binary(root_path) do
    parent_dir = Path.dirname(path)

    candidate =
      if season_directory?(parent_dir, root_path), do: Path.dirname(parent_dir), else: parent_dir

    Path.basename(candidate)
  end

  @doc """
  Cleans a free-form title string by stripping quality/release tokens and
  trailing bracket groups. Port of Jellyfin's `CleanStringParser.Clean`.

  Returns `nil` for empty input or when nothing meaningful remains.
  """
  @spec clean_title(String.t() | nil) :: String.t() | nil
  def clean_title(nil), do: nil

  def clean_title(text) when is_binary(text) do
    text
    |> apply_clean_strings()
    |> normalize_separators()
    |> empty_to_nil()
  end

  # ----------------------------------------------------------------------
  # title_and_year helpers

  # Jellyfin ships a closed list of media extensions in
  # `NamingOptions.VideoFileExtensions`. We mirror the common subset so
  # `Path.rootname` doesn't strip arbitrary trailing dots (e.g. for
  # "My Movie 2013.12.09", an unbounded rootname would lop off ".09").
  @media_extensions ~w(
    .mkv .mp4 .avi .mov .m4v .mpg .mpeg .ogg .ogv .ogm .wmv .flv .webm
    .ts .m2ts .mts .vob .iso .img .bin .nrg .rec .wtv .dvr-ms .3gp .3g2
    .asf .asx .divx .dv .f4v .ifo .m2t .m2v .mxf .nsv .nuv .pva .qt
    .rm .rmvb .strm .svq3 .tp .ty .viv .vp3 .xvid .disc
    .epub .pdf .mobi .azw3 .cbz .cbr
    .mp3 .m4a .m4b .flac .opus .wav .aac
  )

  defp drop_extension(basename) do
    ext = basename |> Path.extname() |> String.downcase()
    if ext in @media_extensions, do: Path.rootname(basename), else: basename
  end

  defp clean_date_time(stem) do
    Enum.find_value(@clean_date_times, {stem, nil}, fn regex ->
      case Regex.run(regex, stem, capture: :all_but_first) do
        [name, year | _] when byte_size(year) == 4 ->
          {name, String.to_integer(year)}

        _ ->
          nil
      end
    end)
  end

  # ----------------------------------------------------------------------
  # parse_episode helpers

  defp build_episode(captures, path) do
    season = captures |> Map.get("seasonnumber") |> parse_int()
    episode = captures |> Map.get("epnumber") |> parse_int()
    series = captures |> Map.get("seriesname") |> blank_to_nil()

    %{}
    |> put_if(:season_number, season)
    |> put_if(:episode_number, episode)
    |> put_if(:tv_show_title, series && clean_title(series))
    |> put_episode_title(captures, path)
  end

  defp put_episode_title(acc, _captures, path) do
    # Jellyfin: episode title is the trailing portion of the stem after the
    # SxxExx marker. We isolate it by splitting the cleaned stem on the
    # season-episode token.
    stem = path |> Path.basename() |> drop_extension()

    case Regex.run(~r/[Ss]\d{1,3}[][ ._-]*[Ee]\d{1,3}[\s._-]+(.+)$/, stem) do
      [_, trailing] -> put_if(acc, :episode_title, clean_title(trailing))
      _ -> acc
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, _rest} -> n
      :error -> nil
    end
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: value)

  defp ensure_leading_slash(path) do
    if String.starts_with?(path, "/"), do: path, else: "/" <> path
  end

  # ----------------------------------------------------------------------
  # tv_show_title_from_path helpers

  defp season_directory?(directory, root_path) do
    expanded_root = Paths.normalize(root_path)
    expanded_dir = Paths.normalize(directory)

    String.starts_with?(expanded_dir, expanded_root) and
      expanded_dir != expanded_root and
      season_name?(Path.basename(directory))
  end

  defp season_name?(name) do
    String.downcase(name) in ["specials", "extras"] or
      pure_numeric?(name) or
      Regex.match?(@season_prefix_regex, name) or
      season_word_match?(name)
  end

  defp pure_numeric?(name) do
    cleaned = String.replace(name, @season_clean_chars, "")
    cleaned != "" and Regex.match?(~r/^\d+$/, cleaned)
  end

  defp season_word_match?(name) do
    # Jellyfin SeasonPathParser.ProcessPost matches "Season N", "S1", localized
    # variants. We restrict to the English forms our libraries are likely to
    # use; extend if needed.
    Regex.match?(~r/^(season|series|s)\s*\d+$/i, name)
  end

  # ----------------------------------------------------------------------
  # clean_title helpers

  defp apply_clean_strings(text) do
    Enum.reduce(@clean_strings, text, fn regex, acc ->
      case Regex.named_captures(regex, acc) do
        %{"cleaned" => cleaned} -> cleaned
        _ -> acc
      end
    end)
  end

  defp normalize_separators(text) do
    text
    |> String.replace([".", "_"], " ")
    |> String.replace(~r/\s+/, " ")
    |> trim_edges()
  end

  defp trim_edges(text) do
    text
    |> String.replace(~r/^[\s\-]+/, "")
    |> String.replace(~r/[\s\-]+$/, "")
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value
end
