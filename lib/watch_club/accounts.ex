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
      define :destroy_user, action: :destroy
    end

    resource WatchClub.Accounts.InvitationCode do
      define :create_invitation_code, action: :create
      define :update_invitation_code, action: :update
      define :delete_invitation_code, action: :destroy
      define :list_invitation_codes, action: :read
      define :view_invitation, action: :view_invitation, args: [:code]
    end

    resource WatchClub.Accounts.ClubInvitation

    resource WatchClub.Accounts.UserSettings do
      define :update_user_settings, action: :update
    end
  end

  def administrator_exists?, do: administrator_exists!()
end
