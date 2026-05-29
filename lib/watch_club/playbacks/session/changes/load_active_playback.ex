defmodule WatchClub.Playbacks.Session.Changes.LoadActivePlayback do
  @moduledoc """
  Loads the Session's `:active_playback` with the HLS-rendering Media graph
  after lifecycle changes, so the returned Session is ready to drive a
  player without a second round-trip.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias WatchClub.MediaCatalog.TextTrack

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, session ->
      Ash.load(
        session,
        [
          active_playback: [
            media: [
              video: [
                :default_video_track,
                audio_tracks: [:display_label],
                text_tracks:
                  TextTrack
                  |> Ash.Query.filter(hls_supported? == true)
                  |> Ash.Query.load(:display_label)
              ]
            ]
          ]
        ],
        reuse_values?: false,
        scope: context
      )
    end)
  end
end
