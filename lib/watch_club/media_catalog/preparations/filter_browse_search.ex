defmodule WatchClub.MediaCatalog.Preparations.FilterBrowseSearch do
  @moduledoc """
  Keeps the Media where each word of the `search` argument is in the path, or in the title as
  the actor sees it, in any order, ignoring case and accents. Words such as `s1`, `e01` or
  `s01e02` match the TV Show Episode's season and episode numbers instead.
  """
  use Ash.Resource.Preparation

  import Ash.Expr

  require Ash.Query

  alias WatchClub.Shared.WordSearch

  # Up to 4 digits, so a number always fits the database's integers
  @episode_number ~r/^(?:s(?<season_number>\d{1,4}))?(?:e(?<episode_number>\d{1,4}))?$/i

  @impl true
  def prepare(query, _opts, _context) do
    {episode_numbers, words} =
      query
      |> Ash.Query.get_argument(:search)
      |> WordSearch.words()
      |> Enum.split_with(&Regex.match?(@episode_number, &1))

    # Such as [season_number: 1, episode_number: 2] for `s01e02`
    episode =
      for word <- episode_numbers,
          {field, number} <- Regex.named_captures(@episode_number, word),
          number != "",
          do: {String.to_existing_atom(field), String.to_integer(number)}

    path_and_title = expr(fragment("concat_ws(' ', ?, ?)", path, content.localized_title_key))
    query = Ash.Query.filter(query, ^WordSearch.contains_every_word(path_and_title, words))

    if episode == [] do
      query
    else
      Ash.Query.filter(query, video: [parts: [tv_show_episode: episode]])
    end
  end
end
