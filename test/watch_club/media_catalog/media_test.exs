defmodule WatchClub.MediaCatalog.MediaTest do
  use WatchClub.DataCase

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

  describe "list_media_under_path_prefix/*" do
    test "returns only media under the given path prefix" do
      movie = seed_movie()

      under =
        create_or_update_video!(video_media_input("tmp/library-a/under.mkv", movie),
          actor: SystemActor.actor()
        )

      _outside =
        create_or_update_video!(video_media_input("tmp/library-b/outside.mkv", movie),
          actor: SystemActor.actor()
        )

      assert [%Media{id: id}] =
               list_media_under_path_prefix!(Path.expand("tmp/library-a"),
                 actor: SystemActor.actor()
               )

      assert id == under.id
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
               create_or_update_ebook!(%{path: path, ebook: %{book_id: book.id}},
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
        create_or_update_ebook!(%{path: path, ebook: %{book_id: original_book.id}},
          actor: SystemActor.actor(),
          load: [:ebook]
        )

      refreshed =
        create_or_update_ebook!(%{path: path, ebook: %{book_id: new_book.id}},
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
               create_or_update_audiobook!(%{path: path, audiobook: %{book_id: book.id}},
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
        create_or_update_audiobook!(%{path: path, audiobook: %{book_id: original_book.id}},
          actor: SystemActor.actor(),
          load: [:audiobook]
        )

      refreshed =
        create_or_update_audiobook!(%{path: path, audiobook: %{book_id: new_book.id}},
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

  describe "browse_media/*" do
    test "returns Media for any authenticated actor" do
      admin = generate(administrator())
      movie = seed_movie()

      m1 =
        create_or_update_video!(video_media_input("tmp/browse/a.mkv", movie),
          actor: SystemActor.actor()
        )

      m2 =
        create_or_update_video!(video_media_input("tmp/browse/b.mkv", movie),
          actor: SystemActor.actor()
        )

      rows = browse_media!(actor: admin)
      ids = Enum.map(rows, & &1.id)
      assert m1.id in ids
      assert m2.id in ids
    end

    test "rejects reads without an actor" do
      browse_media(actor: nil)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "filters by media_type" do
      admin = generate(administrator())
      movie = seed_movie()
      book = seed_book()

      _video =
        create_or_update_video!(video_media_input("tmp/browse/v.mkv", movie),
          actor: SystemActor.actor()
        )

      ebook =
        create_or_update_ebook!(%{path: "tmp/browse/e.epub", ebook: %{book_id: book.id}},
          actor: SystemActor.actor()
        )

      assert [row] = browse_media!(%{media_type: :ebook}, actor: admin)
      assert row.id == ebook.id
    end

    test "search matches the path" do
      admin = generate(administrator())
      movie = seed_movie()

      _a =
        create_or_update_video!(video_media_input("tmp/browse/needle.mkv", movie),
          actor: SystemActor.actor()
        )

      _b =
        create_or_update_video!(video_media_input("tmp/browse/other.mkv", movie),
          actor: SystemActor.actor()
        )

      assert [row] = browse_media!(%{search: "needle"}, actor: admin)
      assert row.path =~ "needle"
    end

    test "search matches the attached Content original_title" do
      admin = generate(administrator())

      content =
        Ash.Seed.seed!(Content, %{
          type: :movie,
          external_id_source: :tmdb,
          external_id: "movie-search-#{System.unique_integer([:positive])}",
          original_title: "Findable Title",
          original_language: "en",
          origin_country: "US"
        })

      movie = Ash.Seed.seed!(Movie, %{id: content.id})

      _ =
        create_or_update_video!(video_media_input("tmp/browse/unrelated.mkv", movie),
          actor: SystemActor.actor()
        )

      assert [row] = browse_media!(%{search: "Findable"}, actor: admin)
      assert row.path =~ "unrelated"
    end

    test "sorts by path asc" do
      admin = generate(administrator())
      movie = seed_movie()

      _a =
        create_or_update_video!(video_media_input("tmp/browse/aaa.mkv", movie),
          actor: SystemActor.actor()
        )

      _b =
        create_or_update_video!(video_media_input("tmp/browse/bbb.mkv", movie),
          actor: SystemActor.actor()
        )

      assert [first, second] =
               browse_media!(%{sort_by: :path, sort_order: :asc}, actor: admin)

      assert first.path =~ "aaa.mkv"
      assert second.path =~ "bbb.mkv"
    end
  end

  defp video_media_input(path, %Movie{} = movie),
    do: video_media_input(path, :movie, %{movie_id: movie.id})

  defp video_media_input(path, %TvShowEpisode{} = episode),
    do: video_media_input(path, :tv_show_episode, %{tv_show_episode_id: episode.id})

  defp video_media_input(path, type, attachment) do
    %{
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
