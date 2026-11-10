defmodule WatchClub.Contents.Preparations.FilterByTitle do
  @moduledoc """
  Keeps the Content whose original title or one of its localized titles contains each word of
  the `query` argument, in any order, ignoring case and accents.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    words =
      query
      |> Ash.Query.get_argument(:query)
      |> String.split(~r/[^[:alnum:]]+/u, trim: true)

    Ash.Query.filter(
      query,
      fragment(
        "NOT EXISTS (SELECT FROM unnest(?::text[]) AS word WHERE strpos(unaccent(lower(?)), unaccent(lower(word))) = 0)",
        ^words,
        original_title
      ) or
        exists(
          movie.localizations,
          fragment(
            "NOT EXISTS (SELECT FROM unnest(?::text[]) AS word WHERE strpos(unaccent(lower(?)), unaccent(lower(word))) = 0)",
            ^words,
            title
          )
        ) or
        exists(
          tv_show.localizations,
          fragment(
            "NOT EXISTS (SELECT FROM unnest(?::text[]) AS word WHERE strpos(unaccent(lower(?)), unaccent(lower(word))) = 0)",
            ^words,
            title
          )
        )
    )
  end
end
