defmodule WatchClub.Languages do
  @moduledoc """
  Shared helpers for rendering language identifiers as human-readable names
  via CLDR.
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
  Returns a flag emoji for a language or territory code via CLDR
  (e.g. `"fre"` → 🇫🇷, `"ja"` → 🇯🇵, `"en"` → 🇺🇸, `"US"` → 🇺🇸).

  Language tags are resolved to their likely territory; bare territory codes
  that aren't valid language tags fall back to `und-XX` resolution so callers
  can pass either form. Returns the UN flag (🇺🇳) when neither resolves.
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
