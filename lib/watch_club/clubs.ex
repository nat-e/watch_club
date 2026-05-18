defmodule WatchClub.Clubs do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.Clubs.{Club, Invitation, Library, LibraryItem, Membership}

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
      define :reorder_libraries, action: :reorder_libraries, args: [:club_id]
      define :update_club, action: :update
    end

    resource Invitation do
      define :create_invitation, action: :create
      define :accept_invitation, action: :accept
      define :destroy_invitation, action: :destroy
      define :list_club_invitations
      define :view_invitation, action: :view_invitation, args: [:id]
    end

    resource Library do
      define :get_library_by_id, action: :read, get_by: [:id]
      define :list_club_libraries, action: :by_club, args: [:club_id]
      define :create_library, action: :create, args: [:club_id]
      define :update_library, action: :update
      define :destroy_library, action: :destroy
    end

    resource LibraryItem do
      define :get_library_items, action: :for_library, args: [:library_id]
    end

    resource Membership do
      define :get_club_membership_by_id, action: :with_club_and_user, get_by: [:id]
      define :leave_club
      define :remove_from_club, action: :destroy
    end
  end
end
