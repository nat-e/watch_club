defmodule WatchClub.Playbacks do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource WatchClub.Playbacks.Session do
      define :start_session, action: :start, args: [:media_id]
      define :start_new_playback, action: :start_new_playback, args: [:media_id]
      define :heartbeat_session, action: :heartbeat
      define :close_session, action: :close
      define :get_session_by_id, action: :read, get_by: [:id]
    end

    resource WatchClub.Playbacks.Playback
  end
end
