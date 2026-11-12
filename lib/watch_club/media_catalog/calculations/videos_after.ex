defmodule WatchClub.MediaCatalog.Calculations.VideosAfter do
  @moduledoc """
  The files a User can play after a Video, in order and at most 10: the rest of the files of its
  Movie, TV Show Episode or Sports Event, then those of the TV Show Episodes with Media after the
  last one it holds. Each file once, with its `parts`. Empty for Unmatched Media.
  """
  use Ash.Resource.Calculation

  alias WatchClub.Contents.Calculations.VideosToPlay
  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.MediaCatalog.{Part, Video}

  @limit 10

  @impl true
  def load(_query, _opts, _context) do
    [
      parts: [
        movie: :videos_to_play,
        sports_event: :videos_to_play,
        tv_show_episode: [
          :videos_to_play,
          playable_episodes_after:
            TvShowEpisode |> Ash.Query.limit(@limit) |> Ash.Query.load(:videos_to_play)
        ]
      ]
    ]
  end

  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(videos, _opts, _context), do: Enum.map(videos, &videos_after/1)

  defp videos_after(%Video{parts: []}), do: []

  defp videos_after(%Video{parts: parts} = video) do
    part = List.last(parts)
    work = Part.work(part)
    {_before, from_it} = VideosToPlay.split_at(work.videos_to_play, video, part)

    following =
      case work do
        %TvShowEpisode{} = episode ->
          Enum.flat_map(episode.playable_episodes_after, & &1.videos_to_play)

        _movie_or_sports_event ->
          []
      end

    (Enum.drop(from_it, 1) ++ following)
    |> Enum.uniq_by(& &1.id)
    |> Enum.take(@limit)
  end
end
