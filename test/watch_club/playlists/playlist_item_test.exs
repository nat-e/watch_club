defmodule WatchClub.Playlists.PlaylistItemTest do
  use WatchClub.DataCase

  import WatchClub.Playlists

  alias WatchClub.Contents.{Content, ContentIdentity}
  alias WatchClub.Playlists.PlaylistItem

  require Ash.Query

  setup do
    owner = generate(user())
    {:ok, owner: owner, playlist: generate(playlist(owner))}
  end

  describe "list_playlist_items/*" do
    test "lists the Playlist Items, newest added first", %{owner: owner, playlist: playlist} do
      older =
        generate(playlist_item(playlist, generate(movie()), added_at: ~U[2026-01-01 00:00:00Z]))

      newer =
        generate(playlist_item(playlist, generate(movie()), added_at: ~U[2026-02-01 00:00:00Z]))

      assert [newer.id, older.id] ==
               Enum.map(list_playlist_items!(playlist.id, actor: owner), & &1.id)
    end

    test "Users it isn't shared with get none", %{playlist: playlist} do
      generate(playlist_item(playlist, generate(movie())))

      assert [] == list_playlist_items!(playlist.id, actor: generate(user()))
    end
  end

  describe "add_to_playlist/*" do
    test "creates the Content WatchClub doesn't have yet and records who added it", %{
      owner: owner,
      playlist: playlist
    } do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Req.Test.json(conn, tmdb_fixture("movie_details_11"))
      end)

      owner_id = owner.id

      assert %PlaylistItem{added_by_id: ^owner_id, content: %Content{external_id: "11"}} =
               add_to_playlist!(playlist.id, ContentIdentity.for_movie(11),
                 load: [:content],
                 actor: owner
               )
    end

    test "Users with Edit access add Content", %{playlist: playlist} do
      editor = generate(user())
      generate(playlist_access(playlist, editor, :edit))
      movie = generate(movie())
      editor_id = editor.id

      assert %PlaylistItem{added_by_id: ^editor_id} =
               add_to_playlist!(playlist.id, ContentIdentity.from_content(movie), actor: editor)
    end

    test "Users with View access can't add Content", %{playlist: playlist} do
      viewer = generate(user())
      generate(playlist_access(playlist, viewer, :view))
      movie = generate(movie())

      add_to_playlist(playlist.id, ContentIdentity.from_content(movie), actor: viewer)
      |> assert_has_error(Ash.Error.Forbidden, fn _error -> true end)
    end
  end

  describe "remove_from_playlist/*" do
    test "Users with Edit access remove Content", %{playlist: playlist} do
      editor = generate(user())
      generate(playlist_access(playlist, editor, :edit))
      movie = generate(movie())
      generate(playlist_item(playlist, movie))

      remove_from_playlist!(playlist.id, movie.id, actor: editor)

      refute PlaylistItem
             |> Ash.Query.filter(content_id == ^movie.id)
             |> Ash.exists?(authorize?: false)
    end

    test "Users with View access can't remove Content", %{playlist: playlist} do
      viewer = generate(user())
      generate(playlist_access(playlist, viewer, :view))
      movie = generate(movie())
      generate(playlist_item(playlist, movie))

      remove_from_playlist(playlist.id, movie.id, actor: viewer)
      |> assert_has_error(Ash.Error.Forbidden, fn _error -> true end)
    end
  end
end
