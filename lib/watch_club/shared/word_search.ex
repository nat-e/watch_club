defmodule WatchClub.Shared.WordSearch do
  @moduledoc """
  Finds text by the words of a search, in any order, ignoring case, accents and punctuation:
  `poulain, amelie` finds "Le Fabuleux Destin d'Amélie Poulain".
  """
  import Ash.Expr

  @doc "The words of a search, without its punctuation."
  @spec words(String.t()) :: [String.t()]
  def words(search), do: String.split(search, ~r/[^[:alnum:]]+/u, trim: true)

  @doc "An expression that is true when the text contains each word. True without words."
  def contains_every_word(text, words) do
    expr(
      fragment(
        "NOT EXISTS (SELECT FROM unnest(?::text[]) AS word WHERE strpos(unaccent(lower(?)), unaccent(lower(word))) = 0)",
        ^words,
        ^text
      )
    )
  end
end
