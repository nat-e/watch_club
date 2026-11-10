defmodule WatchClub.Markers do
  @moduledoc """
  The Markers of Videos, the parts the Player lets a User skip, and how WatchClub
  finds them after each import.
  """

  use Ash.Domain, otp_app: :watch_club

  resources do
    resource WatchClub.Markers.Marker do
      define :detect_markers, action: :detect, args: [:videos]
    end
  end
end
