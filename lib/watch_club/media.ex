defmodule WatchClub.Media do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource WatchClub.Media.Media do
      define :list_media, action: :read
      define :create_video
      define :create_ebook
      define :create_audiobook
      define :destroy_media, action: :destroy
    end

    resource WatchClub.Media.Video
    resource WatchClub.Media.Ebook
    resource WatchClub.Media.Audiobook
    resource WatchClub.Media.VideoTrack
    resource WatchClub.Media.AudioTrack
    resource WatchClub.Media.TextTrack
  end
end
