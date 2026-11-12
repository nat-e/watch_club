defmodule WatchClub.Playbacks.Session.Changes.RecordWatchProgress do
  @moduledoc """
  Records the actor's Watch Progress from a heartbeat's position. Use it on the heartbeat action.

  For each work the Video holds a Part of, it saves the position through all the Parts, as if
  their Videos played one after the other, and the Part and the position in it. Each Video counts
  up to its Credits. Does nothing for Unmatched Media.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents.Calculations.VideosToPlay
  alias WatchClub.History
  alias WatchClub.MediaCatalog.{Media, Part, Video}

  @impl true
  def change(changeset, _opts, context) do
    position = Ash.Changeset.get_argument(changeset, :position_seconds)

    Ash.Changeset.after_action(changeset, fn _changeset, session ->
      %Media{id: media_id, video: video} =
        Ash.load!(
          session,
          [
            current_playback: [
              media: [
                video: [
                  :credits_start_seconds,
                  parts: [
                    movie: :videos_to_play,
                    tv_show_episode: :videos_to_play,
                    sports_event: :videos_to_play
                  ]
                ]
              ]
            ]
          ],
          scope: context
        ).current_playback.media

      part_position =
        case counted_seconds(video) do
          nil -> position
          seconds -> min(position, seconds)
        end

      # One Watch Progress per work the Video holds a Part of
      for part <- Enum.uniq_by(video.parts, &Part.work_id/1) do
        videos = Part.work(part).videos_to_play
        {before, _from_it} = VideosToPlay.split_at(videos, video, part)
        lengths = Enum.map(videos, &counted_seconds/1)

        progress = %{
          last_media_id: media_id,
          position_seconds: Enum.sum_by(before, &(counted_seconds(&1) || 0.0)) + part_position,
          # Unknown while any Video's length is unknown
          duration_seconds: if(nil in lengths, do: nil, else: Enum.sum(lengths)),
          part_number: part.number,
          part_position_seconds: part_position
        }

        progress
        |> Map.merge(Map.take(part, [:movie_id, :tv_show_episode_id, :sports_event_id]))
        |> History.record_watch_progress!(scope: context)
      end

      {:ok, session}
    end)
  end

  # A Video's length up to its Credits, or its full length without Credits
  defp counted_seconds(%Video{} = video),
    do: video.credits_start_seconds || video.duration_seconds
end
