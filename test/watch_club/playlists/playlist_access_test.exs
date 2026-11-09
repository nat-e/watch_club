defmodule WatchClub.Playlists.PlaylistAccessTest do
  use WatchClub.DataCase

  alias WatchClub.Accounts
  alias WatchClub.Playlists
  alias WatchClub.Playlists.PlaylistAccess

  describe "mark_current_user_playlists_seen/*" do
    test "none of the Playlists shared with the User is shared unseen anymore, on their user topic" do
      [user, other] = generate_many(user(), 2)
      user_id = user.id
      playlist = generate(playlist(generate(user())))
      access = generate(playlist_access(playlist, user, :view))
      other_access = generate(playlist_access(playlist, other, :view))
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "user:#{user_id}")

      Playlists.mark_current_user_playlists_seen!(actor: user)

      assert %PlaylistAccess{shared_unseen?: false} = Ash.reload!(access, authorize?: false)
      assert %PlaylistAccess{shared_unseen?: true} = Ash.reload!(other_access, authorize?: false)
      assert %{shared_unseen_playlist_count: 0} = Accounts.get_current_user!(actor: user)

      assert_receive %Ash.Notifier.Notification{
        resource: PlaylistAccess,
        action: %{name: :mark_shared_seen},
        data: %PlaylistAccess{user_id: ^user_id, shared_unseen?: false}
      }
    end
  end
end
