defmodule WatchClub.Languages do
  @moduledoc """
  Shared helpers for comparing language identifiers and rendering them as
  human-readable names via CLDR.
  """

  @doc """
  Returns the localized full name for an ISO 639 language code (e.g. `"eng"`
  or `"en"` → `"English"`). Falls back to canonical-tag resolution, then to
  the uppercase code if CLDR can't resolve the input.
  """
  @spec to_name(String.t() | nil) :: String.t() | nil
  def to_name(nil), do: nil
  def to_name(""), do: nil

  def to_name(language) when is_binary(language) do
    case WatchClub.Cldr.Language.to_string(language) do
      {:ok, name} ->
        name

      _error ->
        case Cldr.Locale.canonical_language_tag(language, WatchClub.Cldr) do
          {:ok, tag} ->
            case WatchClub.Cldr.Language.to_string(tag) do
              {:ok, name} -> name
              _error -> String.upcase(language)
            end

          {:error, _reason} ->
            String.upcase(language)
        end
    end
  end

  @doc """
  Returns the code of a language however its identifier is written, so that
  identifiers from tracks and Metadata Providers compare: the ISO 639-1 code
  when the language has one (`"fre"`, `"fra"` or `"fr-CA"` → `"fr"`).
  Returns nil for an undetermined (`"und"`) or unknown language.
  """
  @spec to_code(String.t() | nil) :: String.t() | nil
  def to_code(nil), do: nil

  def to_code(language) when is_binary(language) do
    case Cldr.Locale.canonical_language_tag(language, WatchClub.Cldr, add_likely_subtags: false) do
      {:ok, %{language: "und"}} -> nil
      {:ok, %{language: code}} -> code
      {:error, _reason} -> nil
    end
  end

  @doc """
  Returns the flag emoji for an ISO 3166-1 alpha-2 country code
  (e.g. `"CA"` → 🇨🇦, `"us"` → 🇺🇸). The flag is the two letters as regional
  indicators, with no language resolution — so it never mistakes a country code
  for a same-spelled language (e.g. `"CA"` is Canada here, not Catalan).

  Use this for country/territory codes; use `to_flag/1` for language codes.
  Returns the UN flag (🇺🇳) for anything that is not a two-letter code.
  """
  @spec country_flag(String.t() | nil) :: String.t()
  def country_flag(code) when is_binary(code) do
    if code =~ ~r/^[A-Za-z]{2}$/, do: flag_emoji(code), else: flag_emoji("UN")
  end

  def country_flag(_), do: flag_emoji("UN")

  @doc """
  Returns a flag emoji for a language code via CLDR by resolving it to its
  likely territory (e.g. `"fre"` → 🇫🇷, `"ja"` → 🇯🇵, `"en"` → 🇺🇸).

  This is for language codes. For country codes use `country_flag/1` instead:
  a two-letter country code can collide with a language code (`"CA"` resolves
  to Catalan → 🇪🇸 here, not Canada). Returns the UN flag (🇺🇳) when the
  language can't be resolved to a territory.
  """
  @spec to_flag(String.t() | nil) :: String.t()
  def to_flag(code) when is_binary(code) and code != "" do
    case resolve_territory(code) do
      nil -> flag_emoji("UN")
      territory -> territory |> Atom.to_string() |> flag_emoji()
    end
  end

  def to_flag(_), do: flag_emoji("UN")

  defp resolve_territory(code) do
    case Cldr.Locale.canonical_language_tag(code, WatchClub.Cldr, add_likely_subtags: true) do
      {:ok, %{territory: territory}} when not is_nil(territory) ->
        territory

      _ ->
        case Cldr.Locale.canonical_language_tag("und-#{code}", WatchClub.Cldr,
               add_likely_subtags: true
             ) do
          {:ok, %{territory: territory}} when not is_nil(territory) -> territory
          _ -> nil
        end
    end
  end

  defp flag_emoji(country_code) do
    country_code
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.map(&(&1 + 127_397))
    |> List.to_string()
  end
end
