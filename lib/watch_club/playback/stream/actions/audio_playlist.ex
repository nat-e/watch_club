defmodule WatchClub.Playback.Stream.Actions.AudioPlaylist do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias WatchClub.Playback.Stream.Actions.Helpers
  alias WatchClub.Playback.Stream.Playlist

  @impl true
  def run(input, _opts, context) do
    with {:ok, stream} <-
           Helpers.fetch_authorized_stream(input.arguments.stream_id, context.actor),
         {:ok, _track} <- Helpers.find_audio_track(stream, input.arguments.track_id) do
      {:ok,
       IO.iodata_to_binary(
         Playlist.segments(
           Helpers.duration(stream),
           Helpers.segment_count(stream),
           Helpers.segment_duration()
         )
       )}
    end
  end
end
