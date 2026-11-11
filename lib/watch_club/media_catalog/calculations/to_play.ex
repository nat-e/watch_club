defmodule WatchClub.MediaCatalog.Calculations.ToPlay do
  @moduledoc """
  What plays after a Video, or before it with `which: :previous`: the next or previous file Play
  plays for its Movie, TV Show Episode or Sports Event, with the `part` it starts with. Past the
  ends of a TV Show Episode, the first file of the next or previous `episode`. Nil when nothing
  plays there, and for Unmatched Media.
  """
  use Ash.Resource.Calculation

  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.MediaCatalog.{Part, Video}

  @impl true
  def load(_query, _opts, _context) do
    [
      parts: [
        movie: :videos_to_play,
        sports_event: :videos_to_play,
        tv_show_episode: [
          :rank,
          :videos_to_play,
          next_episode: [:formatted_episode_number, :videos_to_play],
          previous_episode: [:formatted_episode_number, :videos_to_play]
        ]
      ]
    ]
  end

  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(videos, opts, _context), do: Enum.map(videos, &to_play(&1, opts[:which]))

  defp to_play(%Video{parts: []}, _which), do: nil

  # After the last of the TV Show Episodes a file holds, before the first
  defp to_play(%Video{parts: parts} = video, which) do
    in_order = Enum.sort_by(parts, &{episode_rank(&1), &1.number})
    part = if which == :next, do: List.last(in_order), else: List.first(in_order)
    work = Part.work(part)
    videos = work.videos_to_play

    adjacent =
      case Enum.find_index(videos, &holds?(&1, video, part)) do
        index when which == :next and is_integer(index) ->
          Enum.at(videos, index + 1)

        index when which == :previous and is_integer(index) and index > 0 ->
          Enum.at(videos, index - 1)

        _first_or_none ->
          nil
      end

    case adjacent do
      %Video{} = other ->
        %{
          video: other,
          part: Enum.find(other.parts, &(Part.work_id(&1) == work.id)),
          episode: nil
        }

      _none ->
        to_play_in_episode(work, which)
    end
  end

  defp to_play_in_episode(%TvShowEpisode{} = episode, which) do
    case if(which == :next, do: episode.next_episode, else: episode.previous_episode) do
      %TvShowEpisode{videos_to_play: [video | _]} = other ->
        %{video: video, part: nil, episode: other}

      _none ->
        nil
    end
  end

  defp to_play_in_episode(_movie_or_sports_event, _which), do: nil

  defp episode_rank(%Part{tv_show_episode: %TvShowEpisode{rank: rank}}), do: rank
  defp episode_rank(%Part{}), do: 0

  # The Video itself, or the file Play plays for its Part when the Video is another copy
  defp holds?(%Video{id: id}, %Video{id: id}, _part), do: true
  defp holds?(%Video{parts: parts}, _video, part), do: Enum.any?(parts, &(&1.id == part.id))
end
