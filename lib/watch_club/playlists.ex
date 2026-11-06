defmodule WatchClub.Playlists do
  @moduledoc """
  The Content Users collect in Playlists, private until their owner shares them.
  """
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.Playlists.{Playlist, PlaylistAccess, PlaylistItem}

  resources do
    resource Playlist do
      # Oldest first, so a new User's To Watch comes first
      define :list_playlists, action: :read, default_options: [query: [sort: [inserted_at: :asc]]]
      define :create_playlist, action: :create
      define :update_playlist, action: :update
      define :share_playlist, action: :share, args: [:accesses]
      define :destroy_playlist, action: :destroy
    end

    resource PlaylistItem do
      define :list_playlist_items, action: :for_playlist, args: [:playlist_id]
      define :get_playlist_item, action: :read, get_by: [:playlist_id, :content_id]
      define :add_to_playlist, action: :add, args: [:playlist_id, :content_identity]
      define :remove_from_playlist, action: :destroy, get_by: [:playlist_id, :content_id]
    end

    resource PlaylistAccess
  end
end
