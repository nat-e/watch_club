defmodule WatchClub.Playlists.PlaylistAccessLevel do
  @moduledoc """
  What a `User` can do with a `Playlist` shared with them.
  """
  use Ash.Type.Enum,
    values: [
      view: "Sees the Playlist",
      edit: "Also adds Content to the Playlist and removes it"
    ]
end
