defmodule WatchClub.Clubs do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.Clubs.{Club, Library, LibraryItem, Membership}

  resources do
    resource Club do
      define :list_clubs, action: :read
      define :get_club_by_id, action: :read, get_by: [:id]
      define :preview_club_by_id, action: :preview, get_by: [:id]

      define :create_club, action: :create
      define :destroy_club, action: :destroy
      define :reorder_libraries, args: [:library_ids]
      define :update_club, action: :update
      define :add_club_members, action: :add_members, args: [:user_ids]
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

      define :add_content_to_libraries, args: [:content_identity, :library_ids]
      define :remove_content_from_libraries, args: [:content_identity, :library_ids]
    end

    resource Membership do
      define :get_club_membership_by_id, action: :with_club_and_user, get_by: [:id]
      define :leave_club
      define :remove_from_club, action: :destroy
    end
  end
end
