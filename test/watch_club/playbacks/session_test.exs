defmodule WatchClub.Playbacks.SessionTest do
  use WatchClub.DataCase, async: false

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.{Club, Library, LibraryItem, Membership}
  alias WatchClub.Contents.{Content, Movie}
  alias WatchClub.MediaCatalog.{Media, Video, VideoTrack}
  alias WatchClub.Playbacks
  alias WatchClub.Playbacks.{Playback, Session}
  alias WatchClub.SystemActor

  describe "start_session/*" do
    @tag :tmp_dir
    test "creates a Playback Session and its first Playback for accessible Media",
         %{tmp_dir: tmp_dir} do
      user = generate(user())
      media = accessible_media(user, Path.join(tmp_dir, "start.mkv"))

      assert {:ok,
              %Session{id: session_id, started_by_id: started_by_id, active_playback: playback}} =
               Playbacks.start_session(media.id, load: :active_playback, actor: user)

      assert is_binary(session_id)
      assert started_by_id == user.id
      assert playback.session_id == session_id
      assert playback.media_id == media.id
      assert is_nil(playback.ended_at)
    end

    @tag :tmp_dir
    test "forbids a User whose Clubs have no Library Item for the Content",
         %{tmp_dir: tmp_dir} do
      user = generate(user())
      orphan = orphan_media(Path.join(tmp_dir, "orphan.mkv"))

      Playbacks.start_session(orphan.id, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    @tag :tmp_dir
    test "allows the Instance Administrator to start a Playback Session for any Media",
         %{tmp_dir: tmp_dir} do
      admin = generate(administrator())
      orphan = orphan_media(Path.join(tmp_dir, "admin.mkv"))

      assert {:ok, %Session{active_playback: %Playback{}}} =
               Playbacks.start_session(orphan.id, load: :active_playback, actor: admin)
    end
  end

  describe "start_new_playback/*" do
    @tag :tmp_dir
    test "ends the current Playback and starts a new one on the same Session",
         %{tmp_dir: tmp_dir} do
      user = generate(user())
      first_media = accessible_media(user, Path.join(tmp_dir, "first.mkv"))
      second_media = accessible_media(user, Path.join(tmp_dir, "second.mkv"))

      {:ok, session} =
        Playbacks.start_session(first_media.id, load: :active_playback, actor: user)

      first_playback = session.active_playback

      {:ok, switched} =
        Playbacks.start_new_playback(session, second_media.id,
          load: :active_playback,
          actor: user
        )

      assert switched.id == session.id
      assert switched.active_playback.media_id == second_media.id
      refute switched.active_playback.id == first_playback.id

      reloaded_first = Ash.get!(Playback, first_playback.id, actor: SystemActor.actor())
      refute is_nil(reloaded_first.ended_at)
    end

    @tag :tmp_dir
    test "fails for a User who does not own the Session", %{tmp_dir: tmp_dir} do
      user = generate(user())
      other_user = generate(user())
      first_media = accessible_media(user, Path.join(tmp_dir, "owned.mkv"))
      other_media = accessible_media(other_user, Path.join(tmp_dir, "other.mkv"))

      {:ok, session} =
        Playbacks.start_session(first_media.id, load: :active_playback, actor: user)

      first_playback = session.active_playback

      assert {:error, _} =
               Playbacks.start_new_playback(session, other_media.id, actor: other_user)

      reloaded = Ash.get!(Playback, first_playback.id, actor: SystemActor.actor())
      assert is_nil(reloaded.ended_at)
    end
  end

  describe "heartbeat_session/*" do
    @tag :tmp_dir
    test "updates the current Playback's last active time", %{tmp_dir: tmp_dir} do
      user = generate(user())
      media = accessible_media(user, Path.join(tmp_dir, "heartbeat.mkv"))

      {:ok, session} = Playbacks.start_session(media.id, load: :active_playback, actor: user)
      original = session.active_playback

      Process.sleep(2)

      {:ok, after_beat} =
        Playbacks.heartbeat_session(session, load: :active_playback, actor: user)

      beated = after_beat.active_playback

      assert DateTime.after?(beated.last_active_at, original.last_active_at)
    end

    @tag :tmp_dir
    test "forbids other Users", %{tmp_dir: tmp_dir} do
      user = generate(user())
      other_user = generate(user())
      media = accessible_media(user, Path.join(tmp_dir, "other-user.mkv"))

      {:ok, session} = Playbacks.start_session(media.id, actor: user)

      assert {:error, _} = Playbacks.heartbeat_session(session, actor: other_user)
    end
  end

  def orphan_media(path) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "")
    Ash.Seed.seed!(Media, %{path: Path.expand(path), type: :movie})
  end

  def accessible_media(%User{} = user, path) do
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
    Ash.Seed.seed!(Video, %{id: media.id, movie_id: content.id, duration_seconds: 60.0})

    Ash.Seed.seed!(VideoTrack, %{
      video_id: media.id,
      stream_index: 0,
      codec: "h264",
      width: 1920,
      height: 1080,
      frame_rate: 23.976,
      bit_rate: 5_000_000
    })

    club = Ash.Seed.seed!(Club, %{name: "Club #{System.unique_integer([:positive])}"})
    Ash.Seed.seed!(Membership, %{club_id: club.id, user_id: user.id, role: :member})

    library =
      Ash.Seed.seed!(Library, %{
        club_id: club.id,
        name: "Library #{System.unique_integer([:positive])}",
        content_type: :movie,
        icon: "film",
        index: 0
      })

    Ash.Seed.seed!(LibraryItem, %{library_id: library.id, content_id: content.id})

    media
  end
end
