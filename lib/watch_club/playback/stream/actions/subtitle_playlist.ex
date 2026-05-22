defmodule WatchClub.Playback.Stream.Actions.SubtitlePlaylist do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias WatchClub.Playback.Stream.Actions.Helpers
  alias WatchClub.Playback.Stream.Playlist

  @impl true
  def run(input, _opts, context) do
    with {:ok, stream} <-
           Helpers.fetch_authorized_stream(input.arguments.stream_id, context.actor),
         {:ok, track} <- Helpers.find_subtitle_track(stream, input.arguments.track_id) do
      {:ok, IO.iodata_to_binary(Playlist.subtitle(track, Helpers.duration(stream)))}
    end
  end
end
