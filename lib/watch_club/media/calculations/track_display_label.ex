defmodule WatchClub.Media.Calculations.TrackDisplayLabel do
  @moduledoc """
  Calculates a human-readable label for an Audio Track or Text Track.

  Combines the CLDR-localised language name with the track's `title`, falling
  back to an indexed default (e.g. "Audio 1") when the title is blank.
  Tracks with no language are presented as "und" until CLDR resolves them.
  """

  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [:language, :title]

  @impl true
  def calculate(records, opts, _context) do
    fallback_prefix = Keyword.fetch!(opts, :fallback_prefix)

    records
    |> Enum.with_index()
    |> Enum.map(fn {record, index} ->
      language = record.language || "und"
      language_name = language_name(language)
      fallback = "#{fallback_prefix} #{index + 1}"

      case record.title do
        nil -> "#{language_name} — #{fallback}"
        "" -> "#{language_name} — #{fallback}"
        title -> "#{language_name} — #{title}"
      end
    end)
  end

  defp language_name(language) when is_binary(language) do
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
end
