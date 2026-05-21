defmodule WatchClub.Playback do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource WatchClub.Playback.PlaybackSession do
      define :start_playback_session, action: :start, args: [:media_id]
      define :get_playback_session_by_id, action: :read, get_by: [:id]
      define :get_playback_session_for_playback,
        action: :for_playback,
        get_by: [:id]
      define :heartbeat_playback_session, action: :heartbeat
    end
  end
end
