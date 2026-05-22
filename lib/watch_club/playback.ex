defmodule WatchClub.Playback do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource WatchClub.Playback.Session do
      define :start_session, action: :start, args: [:media_id]
      define :get_session_by_id, action: :read, get_by: [:id]
      define :get_session_for_playback, action: :for_playback, get_by: [:id]
      define :heartbeat_session, action: :heartbeat
    end

    resource WatchClub.Playback.Stream do
      define :start_stream, action: :start, args: [:session_id]
      define :close_stream, action: :close, args: [:stream_id]

      define :get_master_playlist, action: :master_playlist, args: [:stream_id]
      define :get_video_playlist, action: :video_playlist, args: [:stream_id, :variant_id]
      define :get_audio_playlist, action: :audio_playlist, args: [:stream_id, :track_id]
      define :get_subtitle_playlist, action: :subtitle_playlist, args: [:stream_id, :track_id]

      define :get_video_segment,
        action: :video_segment,
        args: [:stream_id, :variant_id, :segment_name]

      define :get_audio_segment,
        action: :audio_segment,
        args: [:stream_id, :track_id, :segment_name]

      define :get_subtitle_file, action: :subtitle_file, args: [:stream_id, :track_id, :file_name]
    end
  end
end
