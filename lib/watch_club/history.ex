defmodule WatchClub.History do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.History.WatchProgress

  require Ash.Query

  resources do
    resource WatchProgress do
      define :record_movie_progress
      define :record_book_progress
      define :record_episode_progress

      define :mark_content_watched, args: [:content_identity]
      define :mark_content_not_watched, args: [:content_identity]
    end
  end
end
