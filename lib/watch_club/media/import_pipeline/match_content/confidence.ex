defmodule WatchClub.Media.ImportPipeline.MatchContent.Confidence do
  @moduledoc """
  Shared helpers used by movie and TV show matching to decide whether a TMDB
  search result is a high-enough-confidence match for the candidate's
  identity.

  Two checks: normalized title equality and year tolerance (delta ≤ 1).
  """

  @year_delta 1

  @doc """
  Strips diacritics, lowercases, trims, and collapses internal whitespace.
  """
  def normalize_title(nil), do: ""

  def normalize_title(title) when is_binary(title) do
    title
    |> String.normalize(:nfd)
    |> String.replace(~r/[\p{Mn}]/u, "")
    |> String.downcase()
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  @doc """
  True when normalized titles match, or when one is a non-empty prefix of the
  other (handles "The Expanse" vs "The Expanse FR" style localized titles).
  """
  def titles_match?(a, b) do
    na = normalize_title(a)
    nb = normalize_title(b)
    na != "" and nb != "" and na == nb
  end

  @doc """
  True when the candidate year and the TMDB result year are within `@year_delta`.
  Either side missing is treated as acceptable — the title check still has to pass.
  """
  def years_match?(nil, _), do: true
  def years_match?(_, nil), do: true

  def years_match?(candidate_year, result_year)
      when is_integer(candidate_year) and is_integer(result_year),
      do: abs(candidate_year - result_year) <= @year_delta

  @doc """
  Pulls the year (integer) out of a `Date`, or returns the integer unchanged,
  or `nil`.
  """
  def date_to_year(nil), do: nil
  def date_to_year(%Date{year: year}), do: year
  def date_to_year(year) when is_integer(year), do: year
end
