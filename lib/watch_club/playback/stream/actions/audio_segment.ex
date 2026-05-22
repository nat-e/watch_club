defmodule WatchClub.Playback.Stream.Actions.AudioSegment do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias WatchClub.Media.Ffmpeg
  alias WatchClub.Playback.Stream.Actions.Helpers

  @impl true
  def run(input, _opts, context) do
    with {:ok, stream} <-
           Helpers.fetch_authorized_stream(input.arguments.stream_id, context.actor),
         {:ok, track} <- Helpers.find_audio_track(stream, input.arguments.track_id),
         {:ok, index} <- Helpers.parse_segment_name(input.arguments.segment_name),
         :ok <- Helpers.validate_segment_index(stream, index) do
      ensure_segment(stream, track, index)
    end
  end

  defp ensure_segment(stream, track, index) do
    output_path = Helpers.audio_segment_path(stream, track, index)

    if Helpers.cached?(output_path) do
      {:ok, output_path}
    else
      Ffmpeg.transcode_audio_segment(%{
        source_path: stream.media.path,
        output_path: output_path,
        start_time: index * Helpers.segment_duration(),
        duration: Helpers.segment_duration_at(stream, index),
        stream_index: track.stream_index
      })
    end
  end
end
