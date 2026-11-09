defmodule WatchClub.Playlists.PlaylistTest do
  use WatchClub.DataCase

  import WatchClub.Playlists

  alias WatchClub.Contents.ContentIdentity
  alias WatchClub.Playlists.{Playlist, PlaylistAccess}

  setup do
    owner = generate(user())
    {:ok, owner: owner, playlist: generate(playlist(owner))}
  end

  describe "list_playlists/*" do
    test "lists the User's Playlists and the ones shared with them, oldest first", %{
      owner: owner,
      playlist: shared
    } do
      user = generate(user())
      generate(playlist_access(shared, user, :view))
      own = generate(playlist(user))
      _private = generate(playlist(owner))

      assert [shared.id, own.id] == Enum.map(list_playlists!(actor: user), & &1.id)
    end

    test "tells whether the User can add and remove its Content", %{
      owner: owner,
      playlist: playlist
    } do
      editor = generate(user())
      viewer = generate(user())
      generate(playlist_access(playlist, editor, :edit))
      generate(playlist_access(playlist, viewer, :view))

      for {user, editable?} <- [{owner, true}, {editor, true}, {viewer, false}] do
        load = [editable_by?: %{user_id: user.id}]
        assert [%Playlist{editable_by?: ^editable?}] = list_playlists!(load: load, actor: user)
      end
    end

    test "tells whether each Playlist holds a Content", %{owner: owner, playlist: playlist} do
      movie = generate(movie())
      generate(playlist_item(playlist, movie))
      other = generate(playlist(owner))
      load = [holds_content?: %{content_identity: ContentIdentity.from_content(movie)}]

      assert [{playlist.id, true}, {other.id, false}] ==
               Enum.map(list_playlists!(load: load, actor: owner), &{&1.id, &1.holds_content?})
    end
  end

  describe "create_playlist/*" do
    test "creates a private Playlist owned by the actor", %{owner: owner} do
      owner_id = owner.id

      assert %Playlist{name: "Sunday movies", icon: "heart", owner_id: ^owner_id, accesses: []} =
               create_playlist!(%{name: "Sunday movies", icon: "heart"},
                 load: [:accesses],
                 actor: owner
               )
    end
  end

  describe "update_playlist/*" do
    test "renames the Playlist and changes its icon", %{owner: owner, playlist: playlist} do
      assert %Playlist{name: "French cinema", icon: "film"} =
               update_playlist!(playlist, %{name: "French cinema", icon: "film"}, actor: owner)
    end

    test "Users it's shared with can't change it", %{playlist: playlist} do
      editor = generate(user())
      generate(playlist_access(playlist, editor, :edit))

      update_playlist(playlist, %{name: "Mine now"}, actor: editor)
      |> assert_has_error(Ash.Error.Forbidden, fn _error -> true end)
    end
  end

  describe "share_playlist/*" do
    test "gives each User their Playlist Access, shared unseen when new, and takes it from the others",
         %{owner: owner, playlist: playlist} do
      [viewer, editor, unshared] = generate_many(user(), 3)
      generate(playlist_access(playlist, editor, :view, shared_unseen?: false))
      generate(playlist_access(playlist, unshared, :edit))

      accesses = [%{user_id: viewer.id, level: :view}, %{user_id: editor.id, level: :edit}]
      playlist = share_playlist!(playlist, accesses, load: [:accesses], actor: owner)

      assert Enum.sort([{viewer.id, :view, true}, {editor.id, :edit, false}]) ==
               playlist.accesses
               |> Enum.map(fn %PlaylistAccess{} = access ->
                 {access.user_id, access.level, access.shared_unseen?}
               end)
               |> Enum.sort()
    end

    test "Users it's shared with can't share it", %{playlist: playlist} do
      [editor, friend] = generate_many(user(), 2)
      generate(playlist_access(playlist, editor, :edit))

      share_playlist(playlist, [%{user_id: friend.id, level: :view}], actor: editor)
      |> assert_has_error(Ash.Error.Forbidden, fn _error -> true end)
    end
  end

  describe "destroy_playlist/*" do
    test "deletes the Playlist, also for the Users it's shared with", %{
      owner: owner,
      playlist: playlist
    } do
      user = generate(user())
      generate(playlist_access(playlist, user, :view))

      destroy_playlist!(playlist, actor: owner)

      assert [] == list_playlists!(actor: user)
    end

    test "Users it's shared with can't delete it", %{playlist: playlist} do
      editor = generate(user())
      generate(playlist_access(playlist, editor, :edit))

      destroy_playlist(playlist, actor: editor)
      |> assert_has_error(Ash.Error.Forbidden, fn _error -> true end)
    end
  end
end
