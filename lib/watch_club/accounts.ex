defmodule WatchClub.Accounts do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource WatchClub.Accounts.Token

    resource WatchClub.Accounts.User do
      define :create_administrator
      define :administrator_exists, action: :administrator_exists?
      define :get_administrator
      define :list_users, action: :read
      define :register_with_password
      define :sign_in, action: :sign_in_with_password
      define :get_current_user
    end
  end

  def administrator_exists?, do: administrator_exists!()
end
