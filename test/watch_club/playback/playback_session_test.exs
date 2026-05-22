defmodule WatchClub.Playback.PlaybackSessionTest do
  use WatchClub.DataCase, async: false

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.{Club, Library, LibraryItem, Membership}
  alias WatchClub.Contents.{Content, Movie}
  alias WatchClub.Media.{Media, Video}
  alias WatchClub.Playback
  alias WatchClub.Playback.PlaybackSession
  alias WatchClub.SystemActor

  describe "start_playback_session/*" do
    test "creates a Playback Session for a selected Media" do
      user = generate(user())
      media = accessible_media(user, "tmp/playback-session-start.mkv")

      assert %PlaybackSession{started_by_id: user_id, media_id: media_id} =
               Playback.start_playback_session!(media.id, actor: user)

      assert user_id == user.id
      assert media_id == media.id
    end

    test "forbids a User whose Clubs have no Library Item for the Content" do
      user = generate(user())
      orphan_media = orphan_media("tmp/playback-session-orphan.mkv")

      Playback.start_playback_session(orphan_media.id, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "allows the Instance Administrator to start a session for any Media" do
      admin = generate(administrator())
      orphan_media = orphan_media("tmp/playback-session-admin-start.mkv")

      assert %PlaybackSession{} =
               Playback.start_playback_session!(orphan_media.id, actor: admin)
    end

    test "forbids the system actor" do
      orphan_media = orphan_media("tmp/playback-session-system-start.mkv")

      Playback.start_playback_session(orphan_media.id, actor: SystemActor.actor())
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "get_playback_session_by_id/*" do
    test "returns the actor's own Playback Session" do
      user = generate(user())
      media = accessible_media(user, "tmp/playback-session-own.mkv")
      session = Playback.start_playback_session!(media.id, actor: user)

      assert %PlaybackSession{id: session_id} =
               Playback.get_playback_session_by_id!(session.id, actor: user)

      assert session_id == session.id
    end

    test "allows the Instance Administrator to inspect Playback Sessions" do
      user = generate(user())
      admin = generate(administrator())
      media = accessible_media(user, "tmp/playback-session-admin.mkv")
      session = Playback.start_playback_session!(media.id, actor: user)

      assert %PlaybackSession{id: session_id} =
               Playback.get_playback_session_by_id!(session.id, actor: admin)

      assert session_id == session.id
    end
  end

  describe "get_playback_session_for_playback/*" do
    test "loads the selected Media for the actor's own Playback Session" do
      user = generate(user())
      media = accessible_media(user, "tmp/playback-session-for-playback.mkv")
      session = Playback.start_playback_session!(media.id, actor: user)

      assert %PlaybackSession{media: %Media{id: media_id}} =
               Playback.get_playback_session_for_playback!(session.id, actor: user)

      assert media_id == media.id
    end
  end

  describe "heartbeat_playback_session/*" do
    test "updates the last active time" do
      user = generate(user())
      media = accessible_media(user, "tmp/playback-session-heartbeat.mkv")
      session = Playback.start_playback_session!(media.id, actor: user)

      Process.sleep(2)

      assert %PlaybackSession{last_active_at: last_active_at} =
               Playback.heartbeat_playback_session!(session, actor: user)

      assert DateTime.after?(last_active_at, session.last_active_at)
    end

    test "forbids other Users" do
      user = generate(user())
      other_user = generate(user())
      media = accessible_media(user, "tmp/playback-session-other-user.mkv")
      session = Playback.start_playback_session!(media.id, actor: user)

      Playback.heartbeat_playback_session(session, actor: other_user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  defp orphan_media(path) do
    Ash.Seed.seed!(Media, %{path: Path.expand(path), type: :video})
  end

  defp accessible_media(%User{} = user, path) do
    media = orphan_media(path)

    content =
      Ash.Seed.seed!(Content, %{
        type: :movie,
        external_id_source: :tmdb,
        external_id: "tmdb-#{System.unique_integer([:positive])}",
        original_title: "Test Movie",
        original_language: "en",
        origin_country: "US"
      })

    Ash.Seed.seed!(Movie, %{id: content.id})
    Ash.Seed.seed!(Video, %{id: media.id, movie_id: content.id})

    club =
      Ash.Seed.seed!(Club, %{
        name: "Club #{System.unique_integer([:positive])}"
      })

    Ash.Seed.seed!(Membership, %{club_id: club.id, user_id: user.id, role: :member})

    library =
      Ash.Seed.seed!(Library, %{
        club_id: club.id,
        name: "Library #{System.unique_integer([:positive])}",
        content_type: :movie,
        icon: WatchClub.Clubs.LibraryIcon.default_for_content_type(:movie),
        index: 0
      })

    Ash.Seed.seed!(LibraryItem, %{library_id: library.id, content_id: content.id})

    media
  end
end
