defmodule WatchClub.MediaCatalog.MediaTest do
  use WatchClub.DataCase

  import ExUnit.CaptureLog
  import WatchClub.MediaCatalog

  alias WatchClub.Contents.{Book, Content, ContentIdentity, Movie, TvShow, TvShowEpisode}

  alias WatchClub.MediaCatalog.{Audiobook, AudioTrack, Ebook, Media, TextTrack, Video, VideoTrack}

  alias WatchClub.Requests.ContentRequest
  alias WatchClub.SystemActor

  require Ash.Query

  describe "list_media/*" do
    test "lists media for an authenticated user" do
      user = generate(user())
      movie = seed_movie()

      media =
        create_or_update_video!(video_media_input("tmp/list.mkv", movie),
          actor: SystemActor.actor()
        )

      assert [%Media{id: id}] = list_media!(actor: user)
      assert id == media.id
    end

    test "rejects reads without an actor" do
      list_media(actor: nil)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "create_or_update_video/*" do
    test "creates video for a movie" do
      movie = seed_movie()
      path = "tmp/media/../movies/star-wars.mkv"
      sidecar_path = "tmp/media/../movies/star-wars.fr.srt"

      assert %Media{
               id: media_id,
               path: normalized_path,
               type: :movie,
               content_id: content_id,
               video: %Video{
                 id: video_id,
                 movie_id: movie_id,
                 duration_seconds: 7245.5,
                 container: "matroska",
                 video_tracks: [%VideoTrack{codec: "h264"}],
                 audio_tracks: [%AudioTrack{codec: "aac", default?: true}],
                 text_tracks: [
                   %TextTrack{stream_index: 2, codec: "subrip"},
                   %TextTrack{sidecar_path: normalized_sidecar_path, codec: "subrip"}
                 ]
               }
             } =
               create_or_update_video!(
                 %{
                   media_source_id: default_media_source_id(),
                   path: path,
                   type: :movie,
                   video: %{
                     movie_id: movie.id,
                     duration_seconds: 7245.5,
                     container: "matroska",
                     bit_rate: 8_000_000,
                     video_tracks: [%{stream_index: 0, codec: "h264", width: 1920, height: 1080}],
                     audio_tracks: [
                       %{
                         stream_index: 1,
                         codec: "aac",
                         language: "eng",
                         channels: 2,
                         default?: true
                       }
                     ],
                     text_tracks: [
                       %{stream_index: 2, codec: "subrip", language: "eng"},
                       %{sidecar_path: sidecar_path, codec: "subrip", language: "fra"}
                     ]
                   }
                 },
                 actor: SystemActor.actor(),
                 load: [video: [:video_tracks, :audio_tracks, :text_tracks]]
               )

      assert media_id == video_id
      assert movie_id == movie.id
      assert content_id == movie.id
      assert normalized_path == Path.expand(path)
      assert normalized_sidecar_path == Path.expand(sidecar_path)
    end

    test "creates video for a TV show episode" do
      episode = seed_tv_show_episode()

      assert %Media{
               type: :tv_show_episode,
               content_id: content_id,
               video: %Video{movie_id: nil, tv_show_episode_id: episode_id}
             } =
               create_or_update_video!(video_media_input("tmp/tv-show.mkv", episode),
                 actor: SystemActor.actor(),
                 load: [:video]
               )

      assert episode_id == episode.id
      assert content_id == episode.tv_show_id
    end

    test "creates an unmatched video" do
      assert %Media{content_id: nil, video: %Video{movie_id: nil, tv_show_episode_id: nil}} =
               create_or_update_video!(
                 video_media_input("tmp/unmatched.mkv", :movie, %{movie_id: nil}),
                 actor: SystemActor.actor(),
                 load: [:video]
               )
    end

    test "preserves subtitles with missing codecs without offering them for playback" do
      input =
        video_media_input("tmp/unknown-subtitle-codec.mkv", :movie, %{movie_id: nil})
        |> put_in([:video, :text_tracks], [
          %{stream_index: 2, codec: nil, language: "eng", title: "Commentary", forced?: true},
          %{stream_index: 3, language: "fra"},
          %{stream_index: 4, codec: "subrip", language: "spa"}
        ])

      tracks = TextTrack |> Ash.Query.load(:hls_supported?) |> Ash.Query.sort(:stream_index)

      media =
        create_or_update_video!(input,
          actor: SystemActor.actor(),
          load: [video: [text_tracks: tracks]]
        )

      assert [
               %TextTrack{
                 stream_index: 2,
                 codec: nil,
                 language: "eng",
                 title: "Commentary",
                 forced?: true,
                 hls_supported?: false
               },
               %TextTrack{stream_index: 3, codec: nil, language: "fra", hls_supported?: false},
               %TextTrack{stream_index: 4, codec: "subrip", hls_supported?: true}
             ] = media.video.text_tracks

      playable =
        get_media!(media.id,
          actor: SystemActor.actor(),
          load: [video: [text_tracks: Ash.Query.filter(TextTrack, hls_supported? == true)]]
        )

      assert [%TextTrack{stream_index: 4}] = playable.video.text_tracks
    end

    test "offers supported external subtitles for playback" do
      input =
        video_media_input("tmp/external-subtitles.mkv", :movie, %{movie_id: nil})
        |> put_in([:video, :text_tracks], [
          %{sidecar_path: "tmp/external-subtitles.srt", codec: "subrip"},
          %{sidecar_path: "tmp/external-subtitles.vtt", codec: "webvtt"},
          %{sidecar_path: "tmp/external-subtitles.ass", codec: "ass"},
          %{sidecar_path: "tmp/external-subtitles.ssa", codec: "ssa"},
          %{sidecar_path: "tmp/external-subtitles.sub", codec: "sub"},
          %{sidecar_path: "tmp/external-subtitles.unknown", codec: nil}
        ])

      tracks = TextTrack |> Ash.Query.filter(hls_supported? == true) |> Ash.Query.sort(:codec)

      media =
        create_or_update_video!(input,
          actor: SystemActor.actor(),
          load: [video: [text_tracks: tracks]]
        )

      assert [
               %TextTrack{codec: "ass"},
               %TextTrack{codec: "ssa"},
               %TextTrack{codec: "subrip"},
               %TextTrack{codec: "webvtt"}
             ] = media.video.text_tracks
    end

    test "replaces an existing video at the same path" do
      movie = seed_movie()
      path = "tmp/refresh.mkv"

      original =
        create_or_update_video!(video_media_input(path, movie),
          actor: SystemActor.actor(),
          load: [video: [:video_tracks, :audio_tracks, :text_tracks]]
        )

      original_track_ids =
        Enum.map(
          original.video.video_tracks ++ original.video.audio_tracks ++ original.video.text_tracks,
          & &1.id
        )

      refreshed =
        create_or_update_video!(
          %{
            media_source_id: default_media_source_id(),
            path: path,
            type: :movie,
            video: %{
              movie_id: movie.id,
              container: "matroska",
              video_tracks: [%{stream_index: 0, codec: "av1", width: 3840, height: 2160}],
              audio_tracks: [
                %{stream_index: 1, codec: "opus", language: "eng", channels: 2, default?: true}
              ],
              text_tracks: []
            }
          },
          actor: SystemActor.actor(),
          load: [video: [:video_tracks, :audio_tracks, :text_tracks]]
        )

      assert refreshed.id == original.id
      assert refreshed.video.id == original.video.id
      assert [%VideoTrack{codec: "av1"}] = refreshed.video.video_tracks
      assert [%AudioTrack{codec: "opus"}] = refreshed.video.audio_tracks
      assert refreshed.video.text_tracks == []

      for old_id <- original_track_ids do
        refute VideoTrack
               |> Ash.Query.filter(id == ^old_id)
               |> Ash.exists?(authorize?: false)

        refute AudioTrack
               |> Ash.Query.filter(id == ^old_id)
               |> Ash.exists?(authorize?: false)

        refute TextTrack
               |> Ash.Query.filter(id == ^old_id)
               |> Ash.exists?(authorize?: false)
      end
    end

    test "gives each Media Source that covers the file its own Media" do
      movie = seed_movie()
      input = video_media_input("tmp/shared.mkv", movie)
      other_media_source = generate(filesystem_media_source())

      media = create_or_update_video!(input, actor: SystemActor.actor())

      other_media =
        create_or_update_video!(%{input | media_source_id: other_media_source.id},
          actor: SystemActor.actor()
        )

      assert other_media.id != media.id
      assert other_media.media_source_id == other_media_source.id
    end

    test "updates the requests of the previous and new Content when a file is re-matched" do
      previous_content = generate(movie())
      new_content = generate(movie())
      path = "tmp/rematch.mkv"

      create_or_update_video!(video_media_input(path, previous_content.movie),
        actor: SystemActor.actor()
      )

      user = generate(user())
      updated_at = ~U[2020-01-01 00:00:00.000000Z]
      previous_request = generate(content_request(user, previous_content, updated_at: updated_at))
      new_request = generate(content_request(user, new_content, updated_at: updated_at))

      create_or_update_video!(video_media_input(path, new_content.movie),
        actor: SystemActor.actor()
      )

      for request <- [previous_request, new_request] do
        reloaded_request = Ash.get!(ContentRequest, request.id, authorize?: false)
        assert DateTime.after?(reloaded_request.updated_at, updated_at)
      end
    end

    test "rejects writes from a non-system actor" do
      user = generate(user())
      movie = seed_movie()

      create_or_update_video(video_media_input("tmp/forbidden.mkv", movie), actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "create_or_update_ebook/*" do
    test "creates ebook for a book" do
      book = seed_book()
      path = "tmp/books/../books/book.epub"

      assert %Media{
               id: media_id,
               path: normalized_path,
               type: :ebook,
               content_id: content_id,
               ebook: %Ebook{id: ebook_id, book_id: book_id}
             } =
               create_or_update_ebook!(
                 %{
                   media_source_id: default_media_source_id(),
                   path: path,
                   ebook: %{book_id: book.id}
                 },
                 actor: SystemActor.actor(),
                 load: [:ebook]
               )

      assert media_id == ebook_id
      assert book_id == book.id
      assert content_id == book.id
      assert normalized_path == Path.expand(path)
    end

    test "replaces an existing ebook at the same path" do
      original_book = seed_book()
      new_book = seed_book()
      path = "tmp/refresh-ebook.epub"

      original =
        create_or_update_ebook!(
          %{
            media_source_id: default_media_source_id(),
            path: path,
            ebook: %{book_id: original_book.id}
          },
          actor: SystemActor.actor(),
          load: [:ebook]
        )

      refreshed =
        create_or_update_ebook!(
          %{
            media_source_id: default_media_source_id(),
            path: path,
            ebook: %{book_id: new_book.id}
          },
          actor: SystemActor.actor(),
          load: [:ebook]
        )

      assert refreshed.id == original.id
      assert refreshed.ebook.id == original.ebook.id
      assert refreshed.ebook.book_id == new_book.id
      assert refreshed.content_id == new_book.id
    end
  end

  describe "create_or_update_audiobook/*" do
    test "creates audiobook for a book" do
      book = seed_book()
      path = "tmp/audiobooks/../audiobooks/book.m4b"

      assert %Media{
               id: media_id,
               path: normalized_path,
               type: :audiobook,
               content_id: content_id,
               audiobook: %Audiobook{id: audiobook_id, book_id: book_id}
             } =
               create_or_update_audiobook!(
                 %{
                   media_source_id: default_media_source_id(),
                   path: path,
                   audiobook: %{book_id: book.id}
                 },
                 actor: SystemActor.actor(),
                 load: [:audiobook]
               )

      assert media_id == audiobook_id
      assert book_id == book.id
      assert content_id == book.id
      assert normalized_path == Path.expand(path)
    end

    test "replaces an existing audiobook at the same path" do
      original_book = seed_book()
      new_book = seed_book()
      path = "tmp/refresh-audiobook.m4b"

      original =
        create_or_update_audiobook!(
          %{
            media_source_id: default_media_source_id(),
            path: path,
            audiobook: %{book_id: original_book.id}
          },
          actor: SystemActor.actor(),
          load: [:audiobook]
        )

      refreshed =
        create_or_update_audiobook!(
          %{
            media_source_id: default_media_source_id(),
            path: path,
            audiobook: %{book_id: new_book.id}
          },
          actor: SystemActor.actor(),
          load: [:audiobook]
        )

      assert refreshed.id == original.id
      assert refreshed.audiobook.id == original.audiobook.id
      assert refreshed.audiobook.book_id == new_book.id
      assert refreshed.content_id == new_book.id
    end
  end

  describe "destroy_media/*" do
    test "deletes the video and its tracks alongside the media" do
      movie = seed_movie()

      media =
        create_or_update_video!(video_media_input("tmp/destroy.mkv", movie),
          actor: SystemActor.actor(),
          load: [video: [:video_tracks, :audio_tracks, :text_tracks]]
        )

      video_track_id = hd(media.video.video_tracks).id
      audio_track_id = hd(media.video.audio_tracks).id
      text_track_id = hd(media.video.text_tracks).id

      content = Ash.get!(Content, movie.id, authorize?: false)

      request =
        generate(
          content_request(generate(user()), content, updated_at: ~U[2020-01-01 00:00:00.000000Z])
        )

      Phoenix.PubSub.subscribe(WatchClub.PubSub, "content:global")

      assert :ok = destroy_media!(media, actor: SystemActor.actor())

      assert DateTime.after?(
               Ash.get!(ContentRequest, request.id, authorize?: false).updated_at,
               request.updated_at
             )

      assert_receive %Ash.Notifier.Notification{
        resource: Media,
        metadata: %{content_id: content_id, content_identity: content_identity}
      }

      assert content_id == content.id
      assert content_identity == ContentIdentity.from_content(content)

      refute Media |> Ash.Query.filter(id == ^media.id) |> Ash.exists?(authorize?: false)
      refute Video |> Ash.Query.filter(id == ^media.id) |> Ash.exists?(authorize?: false)

      refute VideoTrack
             |> Ash.Query.filter(id == ^video_track_id)
             |> Ash.exists?(authorize?: false)

      refute AudioTrack
             |> Ash.Query.filter(id == ^audio_track_id)
             |> Ash.exists?(authorize?: false)

      refute TextTrack |> Ash.Query.filter(id == ^text_track_id) |> Ash.exists?(authorize?: false)
    end
  end

  describe "change_media_path/*" do
    test "moves the Media and notifies the pages showing it" do
      movie = generate(movie())
      media = generate(video_media(movie, path: "/moved/before.mkv"))
      Phoenix.PubSub.subscribe(WatchClub.PubSub, "content:global")

      moved = change_media_path!(media, %{path: "/moved/after.mkv"}, actor: SystemActor.actor())

      assert moved.path == "/moved/after.mkv"

      assert_receive %Ash.Notifier.Notification{
        resource: Media,
        action: %{type: :update},
        metadata: %{content_id: content_id}
      }

      assert content_id == movie.id
    end
  end

  describe "match_media/*" do
    test "matches a Movie file to a Movie by hand" do
      movie = generate(movie())
      media = generate(video_media(nil))

      matched =
        match_media!(media, ContentIdentity.from_content(movie),
          actor: generate(administrator()),
          load: :video
        )

      assert %Media{manually_matched?: true, video: %Video{movie_id: movie_id}} = matched
      assert matched.content_id == movie.id
      assert movie_id == movie.id
    end

    test "matches a TV Show Episode file to an episode of a TV Show by hand" do
      tv_show = generate(tv_show())
      media = generate(video_media(hd(generate(tv_show()).tv_show.episodes)))

      matched =
        match_media!(
          media,
          ContentIdentity.from_content(tv_show),
          %{season_number: 2, episode_number: 3},
          actor: generate(administrator()),
          load: [video: :tv_show_episode]
        )

      assert matched.content_id == tv_show.id

      assert %TvShowEpisode{tv_show_id: tv_show_id, season_number: 2, episode_number: 3} =
               matched.video.tv_show_episode

      assert tv_show_id == tv_show.id
    end

    test "matches a Sports Event file to a Sports Event by hand" do
      sports_event = generate(sports_event())
      media = generate(video_media(nil, type: :sports_event))

      matched =
        match_media!(media, ContentIdentity.from_content(sports_event),
          actor: generate(administrator()),
          load: :video
        )

      assert matched.content_id == sports_event.id
      assert matched.video.sports_event_id == sports_event.id
    end

    test "creates the Movie when WatchClub doesn't have it" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Req.Test.json(conn, Map.put(tmdb_fixture("movie_details_11"), "id", 438_631))
      end)

      media = generate(video_media(nil))

      matched =
        match_media!(media, ContentIdentity.for_movie(438_631),
          actor: generate(administrator()),
          load: :content
        )

      assert ContentIdentity.from_content(matched.content) == ContentIdentity.for_movie(438_631)
    end

    test "returns an error when TMDB can't give the missing Movie" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, &Plug.Conn.send_resp(&1, 503, ""))
      media = generate(video_media(nil))

      capture_log(fn ->
        match_media(media, ContentIdentity.for_movie(438_631), actor: generate(administrator()))
        |> assert_has_error(fn
          %WatchClub.Contents.MetadataUnavailable{} -> true
          _ -> false
        end)
      end)

      assert %Media{content_id: nil, manually_matched?: false} =
               Ash.get!(Media, media.id, authorize?: false)
    end

    test "updates the requests of the previous and new Content" do
      previous_content = generate(movie())
      new_content = generate(movie())
      media = generate(video_media(previous_content))

      user = generate(user())
      updated_at = ~U[2020-01-01 00:00:00.000000Z]
      previous_request = generate(content_request(user, previous_content, updated_at: updated_at))
      new_request = generate(content_request(user, new_content, updated_at: updated_at))

      match_media!(media, ContentIdentity.from_content(new_content),
        actor: generate(administrator())
      )

      assert %ContentRequest{completed?: false} =
               Ash.get!(ContentRequest, previous_request.id, authorize?: false)

      assert %ContentRequest{completed?: true} =
               Ash.get!(ContentRequest, new_request.id, authorize?: false)
    end

    test "rejects actors other than the Instance Administrator" do
      media = generate(video_media(nil))

      match_media(media, ContentIdentity.from_content(generate(movie())), actor: generate(user()))
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "unmatch_media/*" do
    test "makes a manually matched Video Unmatched Media, and updates its Content Request" do
      movie = generate(movie())
      admin = generate(administrator())

      media =
        video_media(nil)
        |> generate()
        |> match_media!(ContentIdentity.from_content(movie), actor: admin)

      updated_at = ~U[2020-01-01 00:00:00.000000Z]
      request = generate(content_request(generate(user()), movie, updated_at: updated_at))

      assert %Media{manually_matched?: false, content_id: nil, video: %Video{movie_id: nil}} =
               unmatch_media!(media, actor: admin, load: :video)

      reloaded_request = Ash.get!(ContentRequest, request.id, authorize?: false)
      assert DateTime.after?(reloaded_request.updated_at, updated_at)
    end

    test "rejects actors other than the Instance Administrator" do
      media = generate(video_media(nil))

      unmatch_media(media, actor: generate(user()))
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "browse_media/*" do
    test "returns one page of Media, with their total" do
      movie = generate(movie())
      generate_many(video_media(movie), 3)

      page = browse_media!(page: [limit: 2, offset: 2], actor: generate(user()))

      assert [%Media{}] = page.results
      assert page.count == 3
    end

    test "rejects reads without an actor" do
      browse_media(page: [limit: 50], actor: nil)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "keeps one Media Type" do
      tv_show = generate(tv_show(num_seasons: 1, episodes_per_season: 1))
      _movie_media = generate(video_media(generate(movie())))
      episode_media = generate(video_media(hd(tv_show.tv_show.episodes)))

      assert [row] =
               browse_media!(%{media_type: :tv_show_episode},
                 page: [limit: 50],
                 actor: generate(user())
               ).results

      assert row.id == episode_media.id
    end

    test "keeps the Unmatched Media" do
      _matched = generate(video_media(generate(movie())))
      unmatched = generate(video_media(nil))

      assert [row] =
               browse_media!(%{unmatched?: true}, page: [limit: 50], actor: generate(user())).results

      assert row.id == unmatched.id
    end

    test "searches each word in the path or the title, in any order" do
      movie = generate(movie(original_title: "Dune"))
      _needle = generate(video_media(movie, path: "/browse/needle-2160p.mkv"))
      _other = generate(video_media(movie, path: "/browse/other.mkv"))

      assert [row] =
               browse_media!(%{search: "2160P dune NEEDLE"},
                 page: [limit: 50],
                 actor: generate(user())
               ).results

      assert row.path == "/browse/needle-2160p.mkv"
    end

    test "searches TV Show Episodes by season and episode number" do
      tv_show =
        generate(tv_show(original_title: "A Show", num_seasons: 2, episodes_per_season: 2))

      medias =
        Map.new(tv_show.tv_show.episodes, fn episode ->
          {{episode.season_number, episode.episode_number}, generate(video_media(episode)).id}
        end)

      browse = fn search ->
        %{search: search}
        |> browse_media!(page: [limit: 50], actor: generate(user()))
        |> Map.fetch!(:results)
        |> MapSet.new(& &1.id)
      end

      assert browse.("show S01E02") == MapSet.new([medias[{1, 2}]])
      assert browse.("e1 s2") == MapSet.new([medias[{2, 1}]])
      assert browse.("s02") == MapSet.new([medias[{2, 1}], medias[{2, 2}]])
      # Too large to be an episode number
      assert browse.("e99999999999999999999") == MapSet.new()
    end

    test "searches the title in the actor's language" do
      movie = generate(movie(titles: %{"fr" => "Les Fils de l'homme"}))
      media = generate(video_media(movie))

      assert [row] =
               browse_media!(%{search: "fils de l'homme"},
                 page: [limit: 50],
                 actor: generate(user(locale: :fr_FR))
               ).results

      assert row.id == media.id

      assert [] =
               browse_media!(%{search: "fils de l'homme"},
                 page: [limit: 50],
                 actor: generate(user(locale: :en_US))
               ).results
    end

    test "sorts by title, with TV Show Episodes in order and Unmatched Media last" do
      tv_show =
        generate(tv_show(original_title: "A Show", num_seasons: 1, episodes_per_season: 2))

      [first_episode, second_episode] =
        Enum.sort_by(tv_show.tv_show.episodes, & &1.episode_number)

      second = generate(video_media(second_episode))
      first = generate(video_media(first_episode))
      movie = generate(video_media(generate(movie(original_title: "B Movie"))))
      unmatched = generate(video_media(nil, path: "/0-unmatched.mkv"))

      browse = fn order ->
        %{sort_by: :title, sort_order: order}
        |> browse_media!(page: [limit: 50], actor: generate(user()))
        |> Map.fetch!(:results)
        |> Enum.map(& &1.id)
      end

      assert browse.(:asc) == [first.id, second.id, movie.id, unmatched.id]
      assert browse.(:desc) == [movie.id, second.id, first.id, unmatched.id]
    end

    test "sorts by date added, the newest first" do
      movie = generate(movie())

      older =
        movie
        |> video_media()
        |> generate()
        |> Ash.Seed.update!(%{inserted_at: ~U[2020-01-01 00:00:00.000000Z]})

      newer = generate(video_media(movie))

      assert [newer.id, older.id] ==
               browse_media!(page: [limit: 50], actor: generate(user())).results
               |> Enum.map(& &1.id)
    end
  end

  describe "count_unmatched_media/*" do
    test "counts the Unmatched Media with the search and Media Type" do
      _needle_a = generate(video_media(nil, path: "/count/needle-a.mkv"))
      _needle_b = generate(video_media(nil, path: "/count/needle-b.mkv"))
      _episode = generate(video_media(nil, path: "/count/needle-c.mkv", type: :tv_show_episode))
      _other = generate(video_media(nil, path: "/count/other.mkv"))
      _matched = generate(video_media(generate(movie()), path: "/count/needle-d.mkv"))

      assert count_unmatched_media!(%{search: "needle", media_type: :movie},
               actor: generate(user())
             ) == 2
    end

    test "rejects counts without an actor" do
      count_unmatched_media(actor: nil)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  defp video_media_input(path, %Movie{} = movie),
    do: video_media_input(path, :movie, %{movie_id: movie.id})

  defp video_media_input(path, %TvShowEpisode{} = episode),
    do: video_media_input(path, :tv_show_episode, %{tv_show_episode_id: episode.id})

  defp video_media_input(path, type, attachment) do
    %{
      media_source_id: default_media_source_id(),
      path: path,
      type: type,
      video:
        Map.merge(attachment, %{
          video_tracks: [%{stream_index: 0, codec: "h264", width: 1920, height: 1080}],
          audio_tracks: [
            %{stream_index: 1, codec: "aac", language: "eng", channels: 2, default?: true}
          ],
          text_tracks: [%{stream_index: 2, codec: "subrip", language: "eng"}]
        })
    }
  end

  defp seed_movie do
    unique = System.unique_integer([:positive])

    content =
      Ash.Seed.seed!(Content, %{
        type: :movie,
        external_id_source: :tmdb,
        external_id: "movie-#{unique}",
        original_title: "Movie #{unique}",
        original_language: "en",
        origin_country: "US"
      })

    Ash.Seed.seed!(Movie, %{id: content.id})
  end

  defp seed_book do
    unique = System.unique_integer([:positive])

    content =
      Ash.Seed.seed!(Content, %{
        type: :book,
        external_id_source: :hardcover,
        external_id: "book-#{unique}",
        original_title: "Book #{unique}",
        original_language: "en",
        origin_country: "US"
      })

    Ash.Seed.seed!(Book, %{id: content.id, title: "Book #{unique}", hardcover_id: unique})
  end

  defp seed_tv_show_episode do
    unique = System.unique_integer([:positive])

    content =
      Ash.Seed.seed!(Content, %{
        type: :tv_show,
        external_id_source: :tmdb,
        external_id: "tv-show-#{unique}",
        original_title: "TV Show #{unique}",
        original_language: "en",
        origin_country: "US"
      })

    tv_show =
      Ash.Seed.seed!(TvShow, %{
        id: content.id,
        original_name: "TV Show #{unique}",
        tmdb_id: unique,
        tvdb_id: unique
      })

    Ash.Seed.seed!(TvShowEpisode, %{
      tv_show_id: tv_show.id,
      season_number: 1,
      episode_number: 1
    })
  end
end
