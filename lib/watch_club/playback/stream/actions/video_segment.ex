defmodule WatchClub.Playback.Stream.Actions.VideoSegment do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias WatchClub.Media.Ffmpeg
  alias WatchClub.Playback.Stream.Actions.Helpers

  @impl true
  def run(input, _opts, context) do
    with {:ok, stream} <-
           Helpers.fetch_authorized_stream(input.arguments.stream_id, context.actor),
         {:ok, quality} <- Helpers.find_quality(stream, input.arguments.variant_id),
         {:ok, index} <- Helpers.parse_segment_name(input.arguments.segment_name),
         :ok <- Helpers.validate_segment_index(stream, index) do
      ensure_segment(stream, quality, index)
    end
  end

  defp ensure_segment(stream, quality, index) do
    output_path = Helpers.video_segment_path(stream, quality, index)

    if Helpers.cached?(output_path) do
      {:ok, output_path}
    else
      Ffmpeg.transcode_video_segment(%{
        source_path: stream.media.path,
        output_path: output_path,
        start_time: index * Helpers.segment_duration(),
        duration: Helpers.segment_duration_at(stream, index),
        segment_duration: Helpers.segment_duration(),
        width: quality.width,
        height: quality.height,
        video_bitrate: quality.video_bitrate
      })
    end
  end
end
