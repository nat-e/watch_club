defmodule WatchClub.Contents.TvShowEpisode.Calculations.FormattedEpisodeNumber do
  @moduledoc """
  Formats a `TvShowEpisode`'s `season_number` and `episode_number` as the
  conventional `S01E01` string used across media tooling.
  """

  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [:season_number, :episode_number]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn %{season_number: s, episode_number: e} ->
      "S#{pad(s)}E#{pad(e)}"
    end)
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")
end
