defmodule WatchClub.MediaCatalog.Preparations.FilterBrowseSearch do
  @moduledoc """
  Keeps the Media where each word of the `search` argument is in the path, or in the title as
  the actor sees it, in any order, ignoring case and accents. Words such as `s1`, `e01` or
  `s01e02` match the TV Show Episode's season and episode numbers instead.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @episode_number ~r/^(?:s(?<season_number>\d+))?(?:e(?<episode_number>\d+))?$/i

  @impl true
  def prepare(query, _opts, _context) do
    {episode_numbers, words} =
      query
      |> Ash.Query.get_argument(:search)
      |> String.split(~r/[^[:alnum:]]+/u, trim: true)
      |> Enum.split_with(&Regex.match?(@episode_number, &1))

    # Such as [season_number: 1, episode_number: 2] for `s01e02`
    episode =
      for word <- episode_numbers,
          {field, number} <- Regex.named_captures(@episode_number, word),
          number != "",
          do: {String.to_existing_atom(field), String.to_integer(number)}

    query =
      Ash.Query.filter(
        query,
        fragment(
          "NOT EXISTS (SELECT FROM unnest(?::text[]) AS word WHERE strpos(unaccent(lower(concat_ws(' ', ?, ?))), unaccent(lower(word))) = 0)",
          ^words,
          path,
          content.localized_title_key
        )
      )

    if episode == [] do
      query
    else
      Ash.Query.filter(query, video: [tv_show_episode: episode])
    end
  end
end
