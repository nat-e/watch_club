defmodule WatchClub.Contents.Calculations.VideosToPlay do
  @moduledoc """
  The files Play plays for a Movie, TV Show Episode or Sports Event, one after another: the oldest
  copy of each Part, in order, skipping the Parts a file before already holds. Each Video comes
  with its `credits_start_seconds` and its `parts`.
  """
  use Ash.Resource.Calculation

  alias WatchClub.MediaCatalog.Video

  @impl true
  def load(_query, _opts, _context), do: [parts: [videos: [:credits_start_seconds, :parts]]]

  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(records, _opts, _context), do: Enum.map(records, &videos_to_play(&1.parts))

  defp videos_to_play(parts) do
    numbers_by_video =
      for part <- parts, video <- part.videos, reduce: %{} do
        numbers -> Map.update(numbers, video.id, [part.number], &[part.number | &1])
      end

    {videos, _held} =
      Enum.reduce(parts, {[], MapSet.new()}, fn part, {videos, held} ->
        if MapSet.member?(held, part.number) do
          {videos, held}
        else
          [video | _copies] = part.videos
          {[video | videos], MapSet.union(held, MapSet.new(numbers_by_video[video.id]))}
        end
      end)

    Enum.reverse(videos)
  end

  @doc """
  Splits the `videos_to_play` of a Movie, TV Show Episode or Sports Event at the playing `video`,
  which holds its `part`: the files before it, and the rest from it. When the `video` is a copy
  Play doesn't play, the file Play plays for its `part` stands for it.
  """
  def split_at(videos_to_play, video, part),
    do: Enum.split_while(videos_to_play, &(not holds?(&1, video, part)))

  defp holds?(%Video{id: id}, %Video{id: id}, _part), do: true
  defp holds?(%Video{parts: parts}, _video, part), do: Enum.any?(parts, &(&1.id == part.id))
end
