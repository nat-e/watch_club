defmodule WatchClub.MediaCatalog.MediaTest do
  use WatchClub.DataCase

  import WatchClub.MediaCatalog

  alias WatchClub.Contents.{Book, Content, Movie, TvShow, TvShowEpisode}

  alias WatchClub.MediaCatalog.{AudioTrack, Audiobook, Ebook, Media, TextTrack, Video, VideoTrack}

  alias WatchClub.SystemActor

  require Ash.Query

  describe "list_media/*" do
    test "lists media for an authenticated user" do
      user = generate(user())
      movie = seed_movie()

      media =
        create_or_update_video!(video_input("tmp/list.mkv", movie), actor: SystemActor.actor())

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
        create_or_update_video!(video_input("tmp/library-a/under.mkv", movie),
          actor: SystemActor.actor()
        )

      _outside =
        create_or_update_video!(video_input("tmp/library-b/outside.mkv", movie),
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
      assert normalized_path == Path.expand(path)
      assert normalized_sidecar_path == Path.expand(sidecar_path)
    end

    test "creates video for a TV show episode" do
      episode = seed_tv_show_episode()

      assert %Media{
               type: :tv_show_episode,
               video: %Video{movie_id: nil, tv_show_episode_id: episode_id}
             } =
               create_or_update_video!(video_input("tmp/tv-show.mkv", episode),
                 actor: SystemActor.actor(),
                 load: [:video]
               )

      assert episode_id == episode.id
    end

    test "replaces an existing video at the same path" do
      movie = seed_movie()
      path = "tmp/refresh.mkv"

      original =
        create_or_update_video!(video_input(path, movie),
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

    test "rejects writes from a non-system actor" do
      user = generate(user())
      movie = seed_movie()

      create_or_update_video(video_input("tmp/forbidden.mkv", movie), actor: user)
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
               ebook: %Ebook{id: ebook_id, book_id: book_id}
             } =
               create_or_update_ebook!(%{path: path, ebook: %{book_id: book.id}},
                 actor: SystemActor.actor(),
                 load: [:ebook]
               )

      assert media_id == ebook_id
      assert book_id == book.id
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
               audiobook: %Audiobook{id: audiobook_id, book_id: book_id}
             } =
               create_or_update_audiobook!(%{path: path, audiobook: %{book_id: book.id}},
                 actor: SystemActor.actor(),
                 load: [:audiobook]
               )

      assert media_id == audiobook_id
      assert book_id == book.id
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
    end
  end

  describe "destroy_media/*" do
    test "deletes the video and its tracks alongside the media" do
      movie = seed_movie()

      media =
        create_or_update_video!(video_input("tmp/destroy.mkv", movie),
          actor: SystemActor.actor(),
          load: [video: [:video_tracks, :audio_tracks, :text_tracks]]
        )

      video_track_id = hd(media.video.video_tracks).id
      audio_track_id = hd(media.video.audio_tracks).id
      text_track_id = hd(media.video.text_tracks).id

      content = Ash.get!(Content, movie.id, authorize?: false)

      Phoenix.PubSub.subscribe(
        WatchClub.PubSub,
        WatchClub.PubSub.content_topic(content.external_id_source, content.external_id)
      )

      assert :ok = destroy_media!(media, actor: SystemActor.actor())

      # The content is resolved before the cascade delete, so the change still broadcasts
      assert_receive %Ash.Notifier.Notification{
        metadata: %{subject: :content_changed, content_id: content_id}
      }

      assert content_id == content.id

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
        create_or_update_video!(video_input("tmp/browse/a.mkv", movie),
          actor: SystemActor.actor()
        )

      m2 =
        create_or_update_video!(video_input("tmp/browse/b.mkv", movie),
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
        create_or_update_video!(video_input("tmp/browse/v.mkv", movie),
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
        create_or_update_video!(video_input("tmp/browse/needle.mkv", movie),
          actor: SystemActor.actor()
        )

      _b =
        create_or_update_video!(video_input("tmp/browse/other.mkv", movie),
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
        create_or_update_video!(video_input("tmp/browse/unrelated.mkv", movie),
          actor: SystemActor.actor()
        )

      assert [row] = browse_media!(%{search: "Findable"}, actor: admin)
      assert row.path =~ "unrelated"
    end

    test "sorts by path asc" do
      admin = generate(administrator())
      movie = seed_movie()

      _a =
        create_or_update_video!(video_input("tmp/browse/aaa.mkv", movie),
          actor: SystemActor.actor()
        )

      _b =
        create_or_update_video!(video_input("tmp/browse/bbb.mkv", movie),
          actor: SystemActor.actor()
        )

      assert [first, second] =
               browse_media!(%{sort_by: :path, sort_order: :asc}, actor: admin)

      assert first.path =~ "aaa.mkv"
      assert second.path =~ "bbb.mkv"
    end

    test "filters by club_id through Movie attachment" do
      admin = generate(administrator())
      club = generate(club(actor: admin))
      library = generate(library(club))
      movie = seed_movie()

      Ash.Seed.seed!(WatchClub.Clubs.LibraryItem, %{
        library_id: library.id,
        content_id: movie.id,
        added_by_id: admin.id
      })

      in_club =
        create_or_update_video!(video_input("tmp/browse/in-club.mkv", movie),
          actor: SystemActor.actor()
        )

      other_movie = seed_movie()

      _out_of_club =
        create_or_update_video!(video_input("tmp/browse/out-of-club.mkv", other_movie),
          actor: SystemActor.actor()
        )

      assert [row] = browse_media!(%{club_id: club.id}, actor: admin)
      assert row.id == in_club.id
    end
  end

  defp video_input(path, %Movie{} = movie),
    do: video_input(path, :movie, %{movie_id: movie.id})

  defp video_input(path, %TvShowEpisode{} = episode),
    do: video_input(path, :tv_show_episode, %{tv_show_episode_id: episode.id})

  defp video_input(path, type, attachment) do
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
