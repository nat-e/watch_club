defmodule WatchClub.History.Calculations.WatchProgressContent do
  @moduledoc """
  An Ash Calculation that retrieves the Content for a WatchProgress object
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    [
      movie: :content,
      book: :content,
      tv_show_episode: [tv_show: :content],
      sports_event: :content
    ]
  end

  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(progresses, _opts, _context) do
    Enum.map(progresses, fn wp ->
      cond do
        wp.movie -> wp.movie.content
        wp.book -> wp.book.content
        wp.tv_show_episode -> wp.tv_show_episode.tv_show.content
        wp.sports_event -> wp.sports_event.content
      end
    end)
  end
end
