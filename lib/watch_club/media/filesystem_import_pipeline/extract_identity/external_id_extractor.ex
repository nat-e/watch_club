defmodule WatchClub.Media.ImportPipeline.ExtractIdentity.ExternalIdExtractor do
  @moduledoc """
  Recognizes IMDB / TMDB / TVDB identifiers in arbitrary text.

  Port of Jellyfin's `MediaBrowser.Common.Providers.ProviderIdParsers` and the
  `[imdbid-tt…]` / `{tmdb-…}` bracket-attribute convention from
  `Emby.Server.Implementations.Library.PathExtensions.GetAttributeValue`.

  Doesn't care whether the text came from a filename, an NFO XML body, or a
  URL — the recognition rules are the same. Callers that already know which
  provider they want can use `find_imdb/1` / `find_tmdb/1` / `find_tvdb/1` to
  skip the others.

  When multiple strategies fire for the same provider, the most explicit
  declaration wins:

      bracket attribute  >  XML tag (`<uniqueid>` / `<tmdbid>` / …)  >  URL  >  bare `tt…`

  Only IMDB has a bare-form scan (`tt\\d{7,8}` is self-identifying). TMDB and
  TVDB IDs are bare integers and would collide with years, episode numbers,
  etc., so they're only recognized when paired with a marker.
  """

  defmodule ExternalIds do
    @type t :: %__MODULE__{
            tmdb: integer() | nil,
            imdb: String.t() | nil,
            tvdb: integer() | nil
          }

    defstruct [:tmdb, :imdb, :tvdb]
  end

  @bracket_regex ~r/[\[\(\{]\s*(tmdbid|tmdb|imdbid|imdb|tvdbid|tvdb)\s*[=\-\s]\s*([^\]\)\}]+?)\s*[\]\)\}]/i
  @uniqueid_regex ~r/<uniqueid[^>]+type=["'](tmdb|imdb|tvdb)["'][^>]*>\s*([^<]+?)\s*<\/uniqueid>/i
  @tag_tmdb_regex ~r/<tmdbid>\s*([^<]+?)\s*<\/tmdbid>/i
  @tag_imdb_regex ~r/<imdbid>\s*([^<]+?)\s*<\/imdbid>/i
  @tag_tvdb_regex ~r/<tvdbid>\s*([^<]+?)\s*<\/tvdbid>/i
  @url_tmdb_regex ~r/themoviedb\.org\/(?:movie|tv)\/(\d+)/i
  @url_tvdb_regex ~r{thetvdb\.com/(?:[^"\s]*?[?&]id=|series/)(\d+)}i
  @url_imdb_regex ~r/imdb\.com\/title\/(tt\d{7,8})/i
  @imdb_bare_regex ~r/tt\d{7,8}/

  @doc """
  Runs every recognition strategy and returns an `%ExternalIds{}` with whatever
  was found. Empty slots stay `nil`.
  """
  @spec from_text(String.t()) :: ExternalIds.t()
  def from_text(text) when is_binary(text) do
    %ExternalIds{
      imdb: find_imdb(text),
      tmdb: to_int(find_tmdb(text)),
      tvdb: to_int(find_tvdb(text))
    }
  end

  defp to_int(nil), do: nil

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> nil
    end
  end

  @doc """
  Finds an IMDB ID in `text`. Returns the lowercased `tt…` form or `nil`.
  """
  @spec find_imdb(String.t()) :: String.t() | nil
  def find_imdb(text) when is_binary(text) do
    with nil <- bracket_value(text, ["imdbid", "imdb"]),
         nil <- uniqueid_value(text, "imdb"),
         nil <- single_capture(text, @tag_imdb_regex),
         nil <- single_capture(text, @url_imdb_regex),
         nil <- single_capture(text, @imdb_bare_regex) do
      nil
    else
      value -> normalize_imdb(value)
    end
  end

  @doc """
  Finds a TMDB ID in `text`. Returns the numeric value as a string, or `nil`.
  """
  @spec find_tmdb(String.t()) :: String.t() | nil
  def find_tmdb(text) when is_binary(text) do
    with nil <- bracket_value(text, ["tmdbid", "tmdb"]),
         nil <- uniqueid_value(text, "tmdb"),
         nil <- single_capture(text, @tag_tmdb_regex) do
      single_capture(text, @url_tmdb_regex)
    end
  end

  @doc """
  Finds a TVDB ID in `text`. Returns the numeric value as a string, or `nil`.
  """
  @spec find_tvdb(String.t()) :: String.t() | nil
  def find_tvdb(text) when is_binary(text) do
    with nil <- bracket_value(text, ["tvdbid", "tvdb"]),
         nil <- uniqueid_value(text, "tvdb"),
         nil <- single_capture(text, @tag_tvdb_regex) do
      single_capture(text, @url_tvdb_regex)
    end
  end

  defp bracket_value(text, providers) do
    @bracket_regex
    |> Regex.scan(text)
    |> Enum.find_value(fn [_match, key, value] ->
      if String.downcase(key) in providers, do: String.trim(value)
    end)
  end

  defp uniqueid_value(text, provider) do
    @uniqueid_regex
    |> Regex.scan(text)
    |> Enum.find_value(fn [_match, type, value] ->
      if String.downcase(type) == provider, do: String.trim(value)
    end)
  end

  defp single_capture(text, regex) do
    case Regex.run(regex, text) do
      [_match, value] -> String.trim(value)
      [value] -> String.trim(value)
      _ -> nil
    end
  end

  defp normalize_imdb(value) do
    case Regex.run(@imdb_bare_regex, value) do
      [match] -> String.downcase(match)
      _ -> nil
    end
  end
end
