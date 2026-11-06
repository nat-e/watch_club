defmodule WatchClub.Contents.Rating do
  @moduledoc """
  A Movie's or TV Show's Rating: the average of its TMDB votes out of 10, to one decimal, so the
  number people see is the one the filters compare. Too few votes give no Rating.
  """

  # Below it, a single vote of 10 would top Best rated
  @min_votes 25

  @doc "The Rating of a TMDB Movie or TV Show, or nil when too few people voted"
  @spec from_tmdb(%{vote_average: number() | nil, vote_count: integer() | nil}) :: float() | nil
  def from_tmdb(%{vote_average: average, vote_count: count})
      when is_number(average) and is_integer(count) and count >= @min_votes,
      do: Float.round(average * 1.0, 1)

  def from_tmdb(_details), do: nil
end
