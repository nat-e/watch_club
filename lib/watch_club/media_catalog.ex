defmodule WatchClub.MediaCatalog do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource WatchClub.MediaCatalog.Media do
      define :list_media, action: :read
      define :browse_media, action: :browse
      define :count_unmatched_media, action: :count_unmatched
      define :get_media, action: :read, get_by: [:id]
      define :get_media_by_path, action: :read, get_by: [:media_source_id, :path]
      define :change_media_path, action: :change_path
      define :match_media, action: :match, args: [:content_identity]
      define :unmatch_media, action: :unmatch
      define :create_or_update_video, action: :create_video
      define :create_or_update_ebook, action: :create_ebook
      define :create_or_update_audiobook, action: :create_audiobook
      define :destroy_media, action: :destroy
    end

    resource WatchClub.MediaCatalog.Video
    resource WatchClub.MediaCatalog.Ebook
    resource WatchClub.MediaCatalog.Audiobook
    resource WatchClub.MediaCatalog.VideoTrack
    resource WatchClub.MediaCatalog.AudioTrack
    resource WatchClub.MediaCatalog.TextTrack
  end
end
