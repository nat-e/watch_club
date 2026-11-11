defmodule WatchClub.Playbacks.Session.Changes.RecordWatchProgress do
  @moduledoc """
  Records the actor's Watch Progress for the current Playback from the heartbeat's
  reported position.

  Upserts the progress of each Movie, TV Show Episode or Sports Event the Playback's Video holds a
  Part of: how far through all its Parts, laid end to end in the order Play plays them, and the
  Part the Video holds with the position in it, where Play resumes. Each file counts up to its
  Credits, so playing the next one from there completes it. No-op for Media without Content.
  """
  use Ash.Resource.Change

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

      # Its first Part of each Movie, TV Show Episode or Sports Event
      for part <- Enum.uniq_by(video.parts, &Part.work_id/1) do
        videos = Part.work(part).videos_to_play
        before = Enum.take_while(videos, &(not holds?(&1, video, part)))
        lengths = Enum.map(videos, &counted_seconds/1)

        progress = %{
          last_media_id: media_id,
          position_seconds: Enum.sum_by(before, &(counted_seconds(&1) || 0.0)) + part_position,
          # Unknown while the length of one of the files is
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

  # The playing Video, or the file Play plays for its Part when the Video is another copy
  defp holds?(%Video{id: id}, %Video{id: id}, _part), do: true
  defp holds?(%Video{parts: parts}, _video, part), do: Enum.any?(parts, &(&1.id == part.id))

  # How long a file counts for: up to its Credits
  defp counted_seconds(%Video{} = video),
    do: video.credits_start_seconds || video.duration_seconds
end
