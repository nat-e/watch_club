defmodule WatchClub.Accounts do
  use Ash.Domain,
    otp_app: :watch_club

  resources do
    resource WatchClub.Accounts.Token
    resource WatchClub.Accounts.User
  end
end
