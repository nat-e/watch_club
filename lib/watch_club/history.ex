defmodule WatchClub.History do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.History.WatchProgress

  require Ash.Query

  resources do
    resource WatchProgress do
      define :record_movie_progress
      define :record_episode_progress
    end
  end
end
