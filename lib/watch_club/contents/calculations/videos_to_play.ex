defmodule WatchClub.Contents.Calculations.VideosToPlay do
  @moduledoc """
  The Videos the Player plays for a Movie, TV Show Episode or Sports Event, one after the other.
  Load it as `videos_to_play`.

  Returns Videos in Part order that hold each Part once: a whole file replaces its halves. Each
  Video comes with its `parts` and `credits_start_seconds`. Empty when there is no Video.
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
    work_part_ids = MapSet.new(parts, & &1.id)

    {videos, _played} =
      Enum.reduce(parts, {[], MapSet.new()}, fn part, {videos, played} ->
        if part.id in played do
          {videos, played}
        else
          video = pick(part.videos, played, work_part_ids)
          held = for other <- video.parts, other.id in work_part_ids, into: played, do: other.id
          {[video | videos], held}
        end
      end)

    Enum.reverse(videos)
  end

  # Picks the copy holding the most Parts, so a whole file wins over its halves, then the oldest.
  # Skips copies holding a Part already played, unless every copy does.
  defp pick([oldest | _] = copies, played, work_part_ids) do
    copies
    |> Enum.reject(fn video -> Enum.any?(video.parts, &(&1.id in played)) end)
    |> Enum.max_by(
      fn video -> Enum.count(video.parts, &(&1.id in work_part_ids)) end,
      &>=/2,
      fn -> oldest end
    )
  end

  @doc """
  Splits `videos_to_play` around the playing `video`, which holds `part`. Returns
  `{videos_before, videos_from_it}`, like `Enum.split_while/2`. When `video` is a copy that isn't
  in the list, it splits at the listed Video holding the same `part`.
  """
  def split_at(videos_to_play, video, part),
    do: Enum.split_while(videos_to_play, &(not holds?(&1, video, part)))

  defp holds?(%Video{id: id}, %Video{id: id}, _part), do: true
  defp holds?(%Video{parts: parts}, _video, part), do: Enum.any?(parts, &(&1.id == part.id))
end
