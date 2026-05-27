defmodule WatchClub.Media do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource WatchClub.Media.Media do
      define :list_media, action: :read
      define :list_media_under_path_prefix, action: :under_path_prefix, args: [:prefix]
      define :browse_media, action: :browse
      define :get_media, action: :read, get_by: [:id]
      define :create_or_update_video, action: :create_video
      define :create_or_update_ebook, action: :create_ebook
      define :create_or_update_audiobook, action: :create_audiobook
      define :destroy_media, action: :destroy
    end

    resource WatchClub.Media.MediaSource do
      define :list_media_sources, action: :read
      define :get_media_source_by_id, action: :read, get_by: [:id]
      define :create_filesystem_media_source, action: :create_filesystem
      define :update_media_source, action: :update
      define :destroy_media_source, action: :destroy
    end

    resource WatchClub.Media.MediaImport do
      define :list_media_imports, action: :read
      define :get_media_import_by_id, action: :read, get_by: [:id]
      define :start_media_import, action: :start, args: [:media_source_id]
      define :cancel_media_import, action: :cancel
    end

    resource WatchClub.Media.Video
    resource WatchClub.Media.Ebook
    resource WatchClub.Media.Audiobook
    resource WatchClub.Media.VideoTrack
    resource WatchClub.Media.AudioTrack
    resource WatchClub.Media.TextTrack
  end
end
