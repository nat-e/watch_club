defmodule WatchClub.Requests.ContentRequest.Calculations.Progress do
  @moduledoc """
  Download progress (0–100): the share of the Content's aired parts that have
  Media — all-or-nothing for a movie, available ÷ aired episodes for a TV
  show.

  An **expression** calculation so it stays pushable to SQL.
  """
  use Ash.Resource.Calculation

  import Ash.Expr

  @impl true
  def expression(_opts, _context) do
    expr(
      cond do
        content.type == :movie ->
          if movie_video_count > 0, do: 100, else: 0

        content.type == :tv_show ->
          if aired_episode_count == 0,
            do: 0,
            else: fragment("(? * 100 / ?)", aired_available_episode_count, aired_episode_count)

        true ->
          0
      end
    )
  end
end
