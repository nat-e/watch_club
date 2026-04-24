defmodule WatchClub.Clubs do
  use Ash.Domain,
    otp_app: :watch_club

  resources do
    resource WatchClub.Clubs.Club do
      define :list_clubs, action: :read
      define :get_club, action: :read, get_by: [:id]
      define :create_club, action: :create
      define :destroy_club, action: :destroy
      define :update_club, action: :update
    end
  end
end
