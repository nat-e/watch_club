defmodule WatchClub.Playback.Stream.Actions.MasterPlaylist do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias WatchClub.Playback.Stream.Actions.Helpers
  alias WatchClub.Playback.Stream.Playlist

  @impl true
  def run(input, _opts, context) do
    with {:ok, stream} <-
           Helpers.fetch_authorized_stream(input.arguments.stream_id, context.actor) do
      metadata = %{
        video: Helpers.video_view(stream),
        audio_tracks: Helpers.audio_tracks(stream),
        subtitle_tracks: Helpers.subtitle_tracks(stream)
      }

      {:ok, IO.iodata_to_binary(Playlist.master(metadata, Helpers.qualities(stream)))}
    end
  end
end
