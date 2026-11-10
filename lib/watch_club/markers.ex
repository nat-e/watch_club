defmodule WatchClub.Markers do
  @moduledoc """
  The Markers of Videos, the parts the Player lets a User skip, and how WatchClub
  finds them after each import.
  """

  use Ash.Domain, otp_app: :watch_club

  resources do
    resource WatchClub.Markers.Marker do
      define :detect_season_markers,
        action: :detect_season,
        args: [:tv_show_id, :season_number]

      define :detect_movie_markers, action: :detect_movie, args: [:movie_id]
    end
  end
end
