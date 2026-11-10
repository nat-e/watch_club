defmodule WatchClub.Playbacks do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource WatchClub.Playbacks.Session do
      define :play, action: :play, args: [:media_id, :screen_id]
      define :play_next, action: :play_next, args: [:screen_id, :playback_id]

      define :heartbeat,
        action: :heartbeat,
        args: [:screen_id, :playback_id, :position_seconds, :paused?]

      define :pick_tracks,
        action: :pick_tracks,
        args: [:playback_id, :audio_track_id, :text_track_id]

      define :cast, action: :cast, args: [:screen_id, :tv_name, :from_screen_id]
      define :leave_screen, action: :leave, args: [:screen_id]
      define :control_tv, action: :control, args: [:command]
      define :stop_casting, action: :end
      define :end_abandoned_sessions, action: :end_abandoned_sessions
      define :get_active_session, action: :active, not_found_error?: false
      define :get_session_by_id, action: :read, get_by: [:id]
      define :list_watching_now, action: :watching_now
    end

    resource WatchClub.Playbacks.Playback do
      define :get_playback_by_id, action: :read, get_by: [:id]
    end

    resource WatchClub.Playbacks.ProblemReport do
      define :report_problem, action: :report
      define :list_problem_reports, action: :list, args: [:archived?]
      define :get_problem_report_by_id, action: :read, get_by: [:id]
      define :archive_problem_report, action: :archive
    end
  end
end
