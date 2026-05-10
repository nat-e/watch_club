defmodule WatchClub.Clubs do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.Clubs.{Club, Invitation, LibraryItem, Membership}

  resources do
    resource Club do
      define :list_clubs, action: :read
      define :get_club_by_id, action: :read, get_by: [:id]
      define :preview_club_by_id, action: :preview, get_by: [:id]

      define :get_members_and_invitations_by_id,
        action: :members_and_invitations,
        get_by: [:id]

      define :create_club, action: :create
      define :destroy_club, action: :destroy
      define :update_club, action: :update
    end

    resource Invitation do
      define :create_invitation, action: :create
      define :accept_invitation, action: :accept
      define :destroy_invitation, action: :destroy
      define :list_club_invitations
      define :view_invitation, action: :view_invitation, args: [:id]
    end

    resource LibraryItem do
      define :add_content_to_club, action: :create, args: [:club_id, :content_id]
      define :remove_content_from_club, action: :destroy
    end

    resource Membership do
      define :get_club_membership_by_id, action: :with_club_and_user, get_by: [:id]
      define :leave_club
      define :remove_from_club, action: :destroy
    end
  end
end
