defmodule WatchClub.Clubs do
  alias WatchClub.Clubs.{Club, Invitation, Membership}

  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource Club do
      define :list_clubs, action: :read
      define :get_club_by_id, action: :read, get_by: [:id]
      define :preview_club_by_id, action: :preview, get_by: [:id]
      define :create_club, action: :create
      define :destroy_club, action: :destroy
      define :update_club, action: :update
    end

    resource Invitation do
      define :invite_user, action: :create
      define :accept_invitation, action: :accept
      define :resend_invitation, action: :resend
      define :cancel_invitation, action: :cancel
      define :list_club_invitations
      define :view_invitation, action: :view_invitation, args: [:id]
    end

    resource Membership do
      define :get_club_memberships, action: :read, get_by: [:club_id]
      define :get_club_membership, action: :read, get_by: [:club_id, :user_id]
    end
  end
end
