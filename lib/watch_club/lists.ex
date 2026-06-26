defmodule WatchClub.Lists do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.Lists.{ContentList, ListItem}

  resources do
    resource ContentList do
      define :get_list_by_id, action: :read, get_by: [:id]
      define :create_list, action: :create
      define :update_list, action: :update
      define :destroy_list, action: :destroy
    end

    resource ListItem do
      define :get_list_items, action: :for_list, args: [:list_id]
      define :get_list_item, action: :read, get_by: [:list_id, :content_id]
      define :get_list_items_by_identities, action: :by_identities, args: [:content_identities]

      define :add_content_to_lists, args: [:content_identity, :list_ids]
      define :destroy_list_item, action: :destroy
    end
  end
end
