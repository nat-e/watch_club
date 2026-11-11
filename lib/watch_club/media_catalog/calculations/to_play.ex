defmodule WatchClub.MediaCatalog.Calculations.ToPlay do
  @moduledoc """
  What plays after a Video, or before it with `which: :previous`: the next or previous file Play
  plays for its Movie, TV Show Episode or Sports Event, with the `part` it starts with. Past the
  ends of a TV Show Episode, the first file of the next or previous `episode`. Nil when nothing
  plays there, and for Unmatched Media.
  """
  use Ash.Resource.Calculation

  alias WatchClub.Contents.Calculations.VideosToPlay
  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.MediaCatalog.{Part, Video}

  @type t :: %__MODULE__{video: Video.t(), part: Part.t() | nil, episode: TvShowEpisode.t() | nil}

  defstruct [:video, :part, :episode]

  @impl true
  def load(_query, _opts, _context) do
    [
      parts: [
        movie: :videos_to_play,
        sports_event: :videos_to_play,
        tv_show_episode: [
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
    part = if which == :next, do: List.last(parts), else: List.first(parts)
    work = Part.work(part)

    adjacent =
      case {which, VideosToPlay.split_at(work.videos_to_play, video, part)} do
        {:next, {_before, [_playing, next | _after]}} -> next
        {:previous, {[_ | _] = before, [_playing | _after]}} -> List.last(before)
        _first_last_or_none -> nil
      end

    case adjacent do
      %Video{} = other ->
        %__MODULE__{video: other, part: Enum.find(other.parts, &(Part.work_id(&1) == work.id))}

      nil ->
        to_play_in_episode(work, which)
    end
  end

  defp to_play_in_episode(%TvShowEpisode{} = episode, which) do
    case if(which == :next, do: episode.next_episode, else: episode.previous_episode) do
      %TvShowEpisode{videos_to_play: [video | _]} = other ->
        %__MODULE__{video: video, episode: other}

      _none ->
        nil
    end
  end

  defp to_play_in_episode(_movie_or_sports_event, _which), do: nil
end
