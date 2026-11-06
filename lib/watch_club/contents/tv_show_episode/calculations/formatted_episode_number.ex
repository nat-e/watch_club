defmodule WatchClub.Contents.TvShowEpisode.Calculations.FormattedEpisodeNumber do
  @moduledoc """
  Formats a `TvShowEpisode`'s `season_number` and `episode_number` with
  `TvShowEpisode.format_number/2`.
  """

  use Ash.Resource.Calculation

  alias WatchClub.Contents.TvShowEpisode

  @impl true
  def load(_query, _opts, _context), do: [:season_number, :episode_number]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &TvShowEpisode.format_number(&1.season_number, &1.episode_number))
  end
end
