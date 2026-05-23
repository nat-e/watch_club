defmodule WatchClub.Media do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource WatchClub.Media.Media do
      define :list_media, action: :read
      define :list_media_under_path_prefix, action: :under_path_prefix, args: [:prefix]
      define :create_or_update_video, action: :create_video
      define :create_or_update_ebook, action: :create_ebook
      define :create_or_update_audiobook, action: :create_audiobook
      define :destroy_media, action: :destroy
    end

    resource WatchClub.Media.ImportConfiguration do
      define :list_import_configurations, action: :read
      define :get_import_configuration_by_id, action: :read, get_by: [:id]
      define :create_filesystem_import_configuration, action: :create_filesystem
      define :update_import_configuration, action: :update
      define :disable_import_configuration, action: :disable
      define :enable_import_configuration, action: :enable
      define :destroy_import_configuration, action: :destroy
    end

    resource WatchClub.Media.ImportRun do
      define :list_import_runs, action: :read
      define :get_import_run_by_id, action: :read, get_by: [:id]
      define :start_import_run, action: :start, args: [:configuration_id]
    end

    resource WatchClub.Media.Video
    resource WatchClub.Media.Ebook
    resource WatchClub.Media.Audiobook
    resource WatchClub.Media.VideoTrack
    resource WatchClub.Media.AudioTrack
    resource WatchClub.Media.TextTrack
  end
end
