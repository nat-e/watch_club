defmodule WatchClub.Playbacks.SessionTest do
  use WatchClub.DataCase, async: false

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.Content
  alias WatchClub.History
  alias WatchClub.History.WatchProgress
  alias WatchClub.Markers.Marker
  alias WatchClub.MediaCatalog.{Media, Video}
  alias WatchClub.Playbacks
  alias WatchClub.Playbacks.{Playback, Session}
  alias WatchClub.Playbacks.Playback.SegmentCache
  alias WatchClub.SystemActor

  describe "play/*" do
    test "starts a Playback Session in the Player, from where the Watch Progress left it" do
      user = generate(user())
      media = movie_media()

      History.record_watch_progress!(
        %{
          movie_id: media.content_id,
          last_media_id: media.id,
          position_seconds: 30.0,
          duration_seconds: 60.0,
          part_number: 1,
          part_position_seconds: 30.0
        },
        actor: user
      )

      session = Playbacks.play!(media.id, "player", load: :current_playback, actor: user)

      assert %Session{screen_id: "player", tv_name: nil, position_seconds: 30.0} = session
      assert session.started_by_id == user.id
      assert session.current_playback.media_id == media.id
    end

    test "resumes in the Part the Watch Progress left, and starts the other Parts from the start" do
      user = generate(user())
      {[first_part, second_part], _next_episode} = two_part_episode_media()

      History.record_watch_progress!(
        %{
          tv_show_episode_id: episode_id(second_part),
          position_seconds: 65.0,
          duration_seconds: 120.0,
          part_number: 2,
          part_position_seconds: 5.0
        },
        actor: user
      )

      assert %Session{position_seconds: 5.0} =
               Playbacks.play!(second_part.id, "player", actor: user)

      assert %Session{position_seconds: +0.0} =
               Playbacks.play!(first_part.id, "player", actor: user)
    end

    test "plays in the active Playback Session, in the Player that plays it" do
      user = generate(user())
      active = generate(playback_session(movie_media(), started_by: user))
      media = movie_media()

      session = Playbacks.play!(media.id, "other-player", load: :current_playback, actor: user)

      assert session.id == active.id
      assert session.screen_id == "other-player"
      assert session.current_playback.media_id == media.id
      assert ended?(active.current_playback)
    end

    test "plays on the TV while the Playback Session plays on a TV" do
      user = generate(user())
      generate(playback_session(movie_media(), started_by: user, screen_id: "tv", tv_name: "TV"))
      media = movie_media()

      session = Playbacks.play!(media.id, "player", load: :current_playback, actor: user)

      assert %Session{screen_id: "tv", tv_name: "TV"} = session
      assert session.current_playback.media_id == media.id
    end

    test "goes on with the current Playback when it already plays the Media there" do
      user = generate(user())
      media = movie_media()
      active = generate(playback_session(media, started_by: user))

      session = Playbacks.play!(media.id, "player", load: :current_playback, actor: user)

      assert session.current_playback.id == active.current_playback.id
    end

    test "forbids a User from playing Unmatched Media" do
      Playbacks.play(unmatched_media().id, "player", actor: generate(user()))
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "lets the Instance Administrator play Unmatched Media" do
      media = unmatched_media()

      session =
        Playbacks.play!(media.id, "player",
          load: :current_playback,
          actor: generate(administrator())
        )

      assert session.current_playback.media_id == media.id
    end

    test "fails for Media that doesn't exist" do
      Playbacks.play(Ash.UUIDv7.generate(), "player", actor: generate(administrator()))
      |> assert_has_error(Ash.Error.Invalid, fn _ -> true end)
    end

    test "starts with the audio and subtitles in the preferred languages" do
      user = generate(user(audio_language: :fr, subtitle_language: :en))

      media =
        movie_media("en",
          audio: [
            %{language: "eng", title: "English", default?: true},
            %{language: "fre", title: "French"}
          ],
          text: [%{language: "fre", title: "French"}, %{language: "eng", title: "English"}]
        )

      assert start_track_titles(media, user) == {"French", "English"}
    end

    test "starts with the audio in the original language" do
      user = generate(user(audio_language: :original))

      media =
        movie_media("ja",
          audio: [
            %{language: "fre", title: "French", default?: true},
            %{language: "jpn", title: "Japanese"}
          ],
          text: []
        )

      assert start_track_titles(media, user) == {"Japanese", nil}
    end

    test "starts with forced subtitles only when the audio is in a language without subtitles" do
      user = generate(user(subtitle_language: :en, languages_without_subtitles: [:en]))

      media =
        movie_media("en",
          audio: [%{language: "eng", title: "English"}],
          text: [
            %{language: "eng", title: "English"},
            %{language: "eng", title: "English forced", forced?: true}
          ]
        )

      assert start_track_titles(media, user) == {"English", "English forced"}
    end

    test "assumes audio without a language is in the original language" do
      user = generate(user(subtitle_language: :fr, languages_without_subtitles: [:fr]))

      media =
        movie_media("fr",
          audio: [
            %{language: "eng", title: "English", default?: true},
            %{language: nil, title: "Untagged"}
          ],
          text: [%{language: "fre", title: "French"}]
        )

      assert start_track_titles(media, user) == {"Untagged", nil}
    end

    test "keeps the audio language and the subtitles of the same Content" do
      user = generate(user(audio_language: :en, subtitle_language: :fr))
      tracks = [audio: [%{language: "eng"}, %{language: "fre"}], text: [%{language: "fre"}]]
      [first, second] = episode_media(tracks)

      generate(
        playback_session(first,
          started_by: user,
          playback: [audio_track_id: audio_track_id(first, "fre"), text_track_id: nil]
        )
      )

      %{current_playback: playback} =
        Playbacks.play!(second.id, "player", load: :current_playback, actor: user)

      assert playback.audio_track_id == audio_track_id(second, "fre")
      assert playback.text_track_id == nil
    end
  end

  describe "play_next/*" do
    test "plays the next TV Show Episode on the same Screen" do
      user = generate(user())
      [first, second] = episode_media()

      session =
        generate(playback_session(first, started_by: user, screen_id: "tv", tv_name: "TV"))

      session =
        Playbacks.play_next!(session, "tv", session.current_playback.id,
          load: :current_playback,
          actor: user
        )

      assert session.screen_id == "tv"
      assert session.current_playback.media_id == second.id
    end

    test "plays the next Part, then the TV Show Episode after it" do
      user = generate(user())
      {[first_part, second_part], next_episode} = two_part_episode_media()
      session = generate(playback_session(first_part, started_by: user))

      session =
        Playbacks.play_next!(session, "player", session.current_playback.id,
          load: :current_playback,
          actor: user
        )

      assert session.current_playback.media_id == second_part.id

      session =
        Playbacks.play_next!(session, "player", session.current_playback.id,
          load: :current_playback,
          actor: user
        )

      assert session.current_playback.media_id == next_episode.id
    end

    test "ends the Playback Session when nothing follows" do
      user = generate(user())
      session = generate(playback_session(movie_media(), started_by: user))

      ended = Playbacks.play_next!(session, "player", session.current_playback.id, actor: user)

      refute is_nil(ended.ended_at)
      assert ended?(session.current_playback)
    end

    test "fails for a Playback that's no longer current" do
      user = generate(user())
      [first, _second] = episode_media()
      session = generate(playback_session(first, started_by: user))

      ended =
        Ash.Seed.seed!(Playback, %{
          session_id: session.id,
          media_id: first.id,
          ended_at: DateTime.utc_now()
        })

      Playbacks.play_next(session, "player", ended.id, actor: user)
      |> assert_has_error(Ash.Error.Invalid, &match?(%Ash.Error.Changes.StaleRecord{}, &1))
    end

    test "fails once the Playback Session ended" do
      user = generate(user())
      now = DateTime.utc_now()

      session =
        generate(
          playback_session(movie_media(),
            started_by: user,
            ended_at: now,
            playback: [ended_at: now]
          )
        )

      Playbacks.play_next(session, "player", session.current_playback.id, actor: user)
      |> assert_has_error(Ash.Error.Invalid, &match?(%Ash.Error.Changes.StaleRecord{}, &1))
    end
  end

  describe "heartbeat/*" do
    test "records where the Screen is at, and the Watch Progress" do
      user = generate(user())
      session = generate(playback_session(movie_media(), started_by: user))

      session =
        Playbacks.heartbeat!(session, "player", session.current_playback.id, 42.0, true,
          actor: user
        )

      assert %Session{position_seconds: 42.0, paused?: true} = session
      assert %WatchProgress{position_seconds: 42.0} = Ash.read_one!(WatchProgress, actor: user)
    end

    test "counts the Watch Progress up to the Credits" do
      user = generate(user())
      media = movie_media()

      Ash.Seed.seed!(Marker, %{
        video_id: media.id,
        kind: :credits,
        start_seconds: 50.0,
        end_seconds: 60.0
      })

      session = generate(playback_session(media, started_by: user))

      Playbacks.heartbeat!(session, "player", session.current_playback.id, 52.0, false,
        actor: user
      )

      assert %WatchProgress{position_seconds: 50.0, duration_seconds: 50.0, completed: true} =
               Ash.read_one!(WatchProgress, load: :completed, actor: user)
    end

    test "records the Watch Progress through every Part, and the Part and where in it" do
      user = generate(user())
      {[_first_part, second_part], _next_episode} = two_part_episode_media()
      session = generate(playback_session(second_part, started_by: user))

      Playbacks.heartbeat!(session, "player", session.current_playback.id, 30.0, false,
        actor: user
      )

      assert %WatchProgress{
               position_seconds: 90.0,
               duration_seconds: 120.0,
               part_number: 2,
               part_position_seconds: 30.0
             } = Ash.read_one!(WatchProgress, actor: user)
    end

    test "records the Watch Progress of each TV Show Episode a file holds" do
      user = generate(user())
      [first, second] = episodes(generate(tv_show(num_seasons: 1, episodes_per_season: 2)))

      media =
        generate(
          video_media(first,
            video: %{
              duration_seconds: 120.0,
              parts: [
                %{tv_show_episode_id: first.id, number: 1},
                %{tv_show_episode_id: second.id, number: 1}
              ]
            }
          )
        )

      session = generate(playback_session(media, started_by: user))

      Playbacks.heartbeat!(session, "player", session.current_playback.id, 30.0, false,
        actor: user
      )

      assert [
               %WatchProgress{position_seconds: 30.0, duration_seconds: 120.0},
               %WatchProgress{position_seconds: 30.0, duration_seconds: 120.0}
             ] = Ash.read!(WatchProgress, actor: user)

      assert MapSet.new(Ash.read!(WatchProgress, actor: user), & &1.tv_show_episode_id) ==
               MapSet.new([first.id, second.id])
    end

    test "fails for a Screen that no longer holds the Playback Session" do
      user = generate(user())
      session = generate(playback_session(movie_media(), started_by: user, screen_id: "other"))

      Playbacks.heartbeat(session, "player", session.current_playback.id, 42.0, false,
        actor: user
      )
      |> assert_has_error(Ash.Error.Invalid, &match?(%Ash.Error.Changes.StaleRecord{}, &1))
    end

    test "fails for a Playback that's no longer current" do
      user = generate(user())
      media = movie_media()
      session = generate(playback_session(media, started_by: user))

      ended =
        Ash.Seed.seed!(Playback, %{
          session_id: session.id,
          media_id: media.id,
          ended_at: DateTime.utc_now()
        })

      Playbacks.heartbeat(session, "player", ended.id, 42.0, false, actor: user)
      |> assert_has_error(Ash.Error.Invalid, &match?(%Ash.Error.Changes.StaleRecord{}, &1))
    end

    test "forbids other Users" do
      session = generate(playback_session(movie_media()))

      Playbacks.heartbeat(session, "player", session.current_playback.id, 42.0, false,
        actor: generate(user())
      )
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "pick_tracks/*" do
    test "switches the current Playback to the tracks" do
      user = generate(user())

      [media | _] =
        episode_media(audio: [%{language: "eng"}, %{language: "fre"}], text: [%{language: "fre"}])

      session = generate(playback_session(media, started_by: user))

      %{current_playback: playback} =
        Playbacks.pick_tracks!(
          session,
          session.current_playback.id,
          audio_track_id(media, "fre"),
          text_track_id(media, "fre"),
          load: :current_playback,
          actor: user
        )

      assert playback.audio_track_id == audio_track_id(media, "fre")
      assert playback.text_track_id == text_track_id(media, "fre")
    end
  end

  describe "cast/*" do
    test "makes the TV the Screen" do
      user = generate(user())
      session = generate(playback_session(movie_media(), started_by: user))

      session = Playbacks.cast!(session, "tv", "Living Room TV", "player", actor: user)

      assert %Session{screen_id: "tv", tv_name: "Living Room TV"} = session
    end

    test "fails once another Screen took the Playback Session" do
      user = generate(user())
      session = generate(playback_session(movie_media(), started_by: user, screen_id: "other"))

      Playbacks.cast(session, "tv", "Living Room TV", "player", actor: user)
      |> assert_has_error(Ash.Error.Invalid, &match?(%Ash.Error.Changes.StaleRecord{}, &1))
    end
  end

  describe "leave_screen/*" do
    test "leaves the Playback Session without a Screen" do
      user = generate(user())

      session =
        generate(
          playback_session(movie_media(), started_by: user, screen_id: "tv", tv_name: "TV")
        )

      session = Playbacks.leave_screen!(session, "tv", actor: user)

      assert %Session{screen_id: nil, tv_name: nil, ended_at: nil} = session
    end
  end

  describe "control_tv/*" do
    test "sends the command to the TV" do
      user = generate(user())

      session =
        generate(
          playback_session(movie_media(), started_by: user, screen_id: "tv", tv_name: "TV")
        )

      Phoenix.PubSub.subscribe(WatchClub.PubSub, "tv:#{session.id}")

      Playbacks.control_tv!(session, :seek, %{position_seconds: 120.0}, actor: user)

      assert_receive {:tv_command, :seek, 120.0}
    end

    test "forbids the Instance Administrator" do
      session = generate(playback_session(movie_media(), screen_id: "tv", tv_name: "TV"))

      Playbacks.control_tv(session, :pause, actor: generate(administrator()))
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "stop_casting/*" do
    test "ends the Playback Session and its Playback" do
      user = generate(user())

      session =
        generate(
          playback_session(movie_media(), started_by: user, screen_id: "tv", tv_name: "TV")
        )

      ended = Playbacks.stop_casting!(session, actor: user)

      refute is_nil(ended.ended_at)
      assert ended?(session.current_playback)
    end
  end

  describe "list_watching_now/*" do
    test "lists the other Users whose Playback Session plays on a Screen, with what it plays" do
      [user, watcher] = generate_many(user(), 2)
      watcher_id = watcher.id
      media = movie_media()
      content_id = media.content_id
      generate(playback_session(media, started_by: watcher))

      assert [
               %{
                 user: %User{id: ^watcher_id},
                 content: %Content{id: ^content_id},
                 tv_show_episode: nil
               }
             ] = Playbacks.list_watching_now!(actor: user)
    end

    test "leaves out the actor, the Playback Sessions without a Screen, the ended ones and the Unmatched Media" do
      user = generate(user())
      generate(playback_session(movie_media(), started_by: user))

      generate(
        playback_session(movie_media(),
          last_heartbeat_at: DateTime.add(DateTime.utc_now(), -1, :minute)
        )
      )

      generate(playback_session(movie_media(), ended_at: DateTime.utc_now()))
      generate(playback_session(unmatched_media()))

      assert [] = Playbacks.list_watching_now!(actor: user)
    end
  end

  describe "end_abandoned_sessions/*" do
    test "ends the Playback Sessions without a Screen for two minutes and removes their segment cache" do
      abandoned =
        generate(
          playback_session(movie_media(),
            last_heartbeat_at: DateTime.add(DateTime.utc_now(), -3, :minute)
          )
        )

      active =
        generate(
          playback_session(movie_media(),
            last_heartbeat_at: DateTime.add(DateTime.utc_now(), -1, :minute)
          )
        )

      File.mkdir_p!(SegmentCache.playback_dir(abandoned.current_playback.id))
      File.mkdir_p!(SegmentCache.playback_dir(active.current_playback.id))

      Playbacks.end_abandoned_sessions!(actor: SystemActor.actor())

      refute is_nil(Ash.get!(Session, abandoned.id, actor: SystemActor.actor()).ended_at)
      assert is_nil(Ash.get!(Session, active.id, actor: SystemActor.actor()).ended_at)
      refute File.exists?(SegmentCache.playback_dir(abandoned.current_playback.id))
      assert File.exists?(SegmentCache.playback_dir(active.current_playback.id))
    end

    test "forbids Users" do
      Playbacks.end_abandoned_sessions(actor: generate(user()))
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  # Media for a Movie in the original language, whose Video has the given tracks
  defp movie_media(original_language \\ "en", tracks \\ [audio: [%{language: "eng"}], text: []]) do
    generate(movie(original_language: original_language))
    |> video_media(video: video_tracks(tracks))
    |> generate()
  end

  # The two Media holding the Parts of a TV Show Episode, a minute each, and the Media of the
  # episode after it
  defp two_part_episode_media do
    [episode, next_episode] = episodes(generate(tv_show(num_seasons: 1, episodes_per_season: 2)))

    parts =
      for number <- [1, 2] do
        generate(
          video_media(episode,
            video: %{
              duration_seconds: 60.0,
              parts: [%{tv_show_episode_id: episode.id, number: number}]
            }
          )
        )
      end

    {parts, generate(video_media(next_episode, video: %{duration_seconds: 60.0}))}
  end

  defp episodes(tv_show), do: Enum.sort_by(tv_show.tv_show.episodes, & &1.episode_number)

  defp episode_id(media) do
    [part] = Ash.load!(media, [video: :parts], authorize?: false).video.parts
    part.tv_show_episode_id
  end

  # Media for two TV Show Episodes in a row, whose Videos have the given tracks
  defp episode_media(tracks \\ [audio: [%{language: "eng"}], text: []]) do
    generate(tv_show(num_seasons: 1, episodes_per_season: 2)).tv_show.episodes
    |> Enum.sort_by(& &1.episode_number)
    |> Enum.map(&generate(video_media(&1, video: video_tracks(tracks))))
  end

  defp video_tracks(audio: audio_tracks, text: text_tracks) do
    %{
      audio_tracks:
        Enum.with_index(audio_tracks, &Map.merge(%{stream_index: &2 + 1, codec: "aac"}, &1)),
      text_tracks:
        Enum.with_index(text_tracks, &Map.merge(%{stream_index: &2 + 10, codec: "subrip"}, &1))
    }
  end

  defp unmatched_media do
    media =
      Ash.Seed.seed!(Media, %{
        media_source_id: default_media_source_id(),
        path: "/library/#{System.unique_integer([:positive])}.mkv",
        type: :movie
      })

    Ash.Seed.seed!(Video, %{id: media.id, file_fingerprint: "fingerprint", duration_seconds: 60.0})

    media
  end

  # The titles of the Audio Track and Text Track the User's Playback of the Media starts with
  defp start_track_titles(media, user) do
    %{current_playback: playback} =
      Playbacks.play!(media.id, "player",
        load: [current_playback: [:audio_track, :text_track]],
        actor: user
      )

    {playback.audio_track && playback.audio_track.title,
     playback.text_track && playback.text_track.title}
  end

  defp audio_track_id(media, language) do
    Ash.load!(media, [video: :audio_tracks], authorize?: false).video.audio_tracks
    |> Enum.find(&(&1.language == language))
    |> Map.fetch!(:id)
  end

  defp text_track_id(media, language) do
    Ash.load!(media, [video: :text_tracks], authorize?: false).video.text_tracks
    |> Enum.find(&(&1.language == language))
    |> Map.fetch!(:id)
  end

  defp ended?(%Playback{id: id}),
    do: not is_nil(Ash.get!(Playback, id, actor: SystemActor.actor()).ended_at)
end
