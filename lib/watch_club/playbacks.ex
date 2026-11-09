defmodule WatchClub.Playbacks do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource WatchClub.Playbacks.Session do
      define :start_session, action: :start, args: [:media_id]
      define :start_new_playback, action: :start_new_playback, args: [:media_id]
      define :heartbeat_session, action: :heartbeat
      define :end_inactive_playbacks, action: :end_inactive_playbacks
      define :get_session_by_id, action: :read, get_by: [:id]
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
