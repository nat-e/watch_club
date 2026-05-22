defmodule WatchClub.Playback.Stream.Actions.SubtitleFile do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias WatchClub.Media.Ffmpeg
  alias WatchClub.Playback.Stream.Actions.Helpers

  @impl true
  def run(input, _opts, context) do
    with {:ok, stream} <-
           Helpers.fetch_authorized_stream(input.arguments.stream_id, context.actor),
         {:ok, track} <- Helpers.find_subtitle_track(stream, input.arguments.track_id),
         :ok <- ensure_expected_file(track, input.arguments.file_name) do
      ensure_file(stream, track)
    end
  end

  defp ensure_expected_file(track, file_name) do
    if file_name == track.file_name do
      :ok
    else
      {:error, :not_found}
    end
  end

  defp ensure_file(stream, track) do
    output_path = Helpers.subtitle_file_path(stream, track)

    if Helpers.cached?(output_path) do
      {:ok, output_path}
    else
      Ffmpeg.transcode_subtitle_file(%{
        source_path: stream.media.path,
        output_path: output_path,
        stream_index: track.stream_index
      })
    end
  end
end
