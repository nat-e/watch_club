defmodule WatchClub.Media.MediaTest do
  use WatchClub.DataCase

  import WatchClub.Media

  alias WatchClub.Contents.{Book, Content, Movie, TvShow, TvShowEpisode}

  alias WatchClub.Media.{
    AudioTrack,
    Audiobook,
    Ebook,
    ImportConfiguration,
    ImportRun,
    Media,
    TextTrack,
    Video,
    VideoTrack
  }

  alias WatchClub.SystemActor

  require Ash.Query

  describe "create_video/*" do
    test "creates video media with tracks" do
      movie = seed_movie()
      path = "tmp/media/../movies/star-wars.mkv"
      sidecar_path = "tmp/media/../movies/star-wars.en.srt"

      assert %Media{
               id: media_id,
               path: normalized_path,
               type: :video,
               video: %Video{
                 id: video_id,
                 movie_id: movie_id,
                 duration_seconds: 7245.5,
                 container: "matroska",
                 bit_rate: 8_000_000,
                 video_tracks: [
                   %VideoTrack{
                     stream_index: 0,
                     codec: "h264",
                     width: 1920,
                     height: 1080,
                     frame_rate: 23.976,
                     bit_rate: 7_500_000
                   }
                 ],
                 audio_tracks: [
                   %AudioTrack{
                     stream_index: 1,
                     codec: "aac",
                     language: "eng",
                     title: "Stereo",
                     channels: 2,
                     default?: true
                   }
                 ],
                 text_tracks: [
                   %TextTrack{
                     stream_index: 2,
                     codec: "subrip",
                     language: "eng",
                     title: "English",
                     default?: true,
                     forced?: false
                   },
                   %TextTrack{
                     stream_index: nil,
                     sidecar_path: normalized_sidecar_path,
                     codec: "subrip",
                     language: "fra",
                     title: "French",
                     default?: false,
                     forced?: false
                   }
                 ]
               }
             } =
               create_video!(
                 %{
                   path: path,
                   video: %{
                     movie_id: movie.id,
                     duration_seconds: 7245.5,
                     container: "matroska",
                     bit_rate: 8_000_000,
                     video_tracks: [
                       %{
                         stream_index: 0,
                         codec: "h264",
                         width: 1920,
                         height: 1080,
                         frame_rate: 23.976,
                         bit_rate: 7_500_000
                       }
                     ],
                     audio_tracks: [
                       %{
                         stream_index: 1,
                         codec: "aac",
                         language: "eng",
                         title: "Stereo",
                         channels: 2,
                         default?: true
                       }
                     ],
                     text_tracks: [
                       %{
                         stream_index: 2,
                         codec: "subrip",
                         language: "eng",
                         title: "English",
                         default?: true,
                         forced?: false
                       },
                       %{
                         sidecar_path: sidecar_path,
                         codec: "subrip",
                         language: "fra",
                         title: "French"
                       }
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

    test "creates video media for a TV Show Episode" do
      tv_show_episode = seed_tv_show_episode()

      assert %Media{
               id: media_id,
               type: :video,
               video: %Video{
                 id: video_id,
                 movie_id: nil,
                 tv_show_episode_id: tv_show_episode_id
               }
             } =
               create_video!(video_input("tmp/tv-show-episode.mkv", tv_show_episode),
                 actor: SystemActor.actor(),
                 load: [:video]
               )

      assert media_id == video_id
      assert tv_show_episode_id == tv_show_episode.id
    end

    test "rejects duplicate normalized paths" do
      movie = seed_movie()
      path = "tmp/media/../movies/duplicate.mkv"

      create_video!(video_input(path, movie), actor: SystemActor.actor())

      create_video(video_input(Path.expand(path), movie), actor: SystemActor.actor())
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :path} -> true
        _ -> false
      end)
    end

    test "forbids non-system actors from creating video media" do
      user = generate(user())
      movie = seed_movie()

      create_video(video_input("tmp/member-video.mkv", movie), actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "create_ebook/*" do
    test "creates ebook media" do
      book = seed_book()
      path = "tmp/books/../books/book.epub"

      assert %Media{
               id: media_id,
               path: normalized_path,
               type: :ebook,
               ebook: %Ebook{id: ebook_id, book_id: book_id}
             } =
               create_ebook!(%{path: path, ebook: %{book_id: book.id}},
                 actor: SystemActor.actor(),
                 load: [:ebook]
               )

      assert media_id == ebook_id
      assert book_id == book.id
      assert normalized_path == Path.expand(path)
    end
  end

  describe "create_audiobook/*" do
    test "creates audiobook media" do
      book = seed_book()
      path = "tmp/audiobooks/../audiobooks/book.m4b"

      assert %Media{
               id: media_id,
               path: normalized_path,
               type: :audiobook,
               audiobook: %Audiobook{id: audiobook_id, book_id: book_id}
             } =
               create_audiobook!(%{path: path, audiobook: %{book_id: book.id}},
                 actor: SystemActor.actor(),
                 load: [:audiobook]
               )

      assert media_id == audiobook_id
      assert book_id == book.id
      assert normalized_path == Path.expand(path)
    end
  end

  describe "list_media/*" do
    test "lists media for any authenticated actor" do
      user = generate(user())
      movie = seed_movie()
      media = create_video!(video_input("tmp/list-media.mkv", movie), actor: SystemActor.actor())

      assert [%Media{id: media_id, video: %Video{id: video_id}}] =
               list_media!(actor: user, load: [:video])

      assert media_id == media.id
      assert video_id == media.id
    end
  end

  describe "update_video/*" do
    test "updates the concrete Video in place and rebuilds tracks" do
      movie = seed_movie()

      media =
        create_video!(video_input("tmp/media/refresh.mkv", movie),
          actor: SystemActor.actor(),
          load: [video: [:video_tracks, :audio_tracks, :text_tracks]]
        )

      original_media_id = media.id
      original_video_id = media.video.id
      original_path = media.path
      old_track_id = media.video.video_tracks |> List.first() |> Map.fetch!(:id)

      assert %Media{video: %Video{video_tracks: [%VideoTrack{codec: "av1"}]}} =
               updated_media =
               update_video!(
                 media,
                 %{
                   video: %{
                     movie_id: movie.id,
                     duration_seconds: 7000.0,
                     container: "matroska",
                     bit_rate: 5_000_000,
                     video_tracks: [
                       %{stream_index: 0, codec: "av1", width: 3840, height: 2160}
                     ],
                     audio_tracks: [
                       %{
                         stream_index: 1,
                         codec: "opus",
                         language: "eng",
                         channels: 2,
                         default?: true
                       }
                     ],
                     text_tracks: []
                   }
                 },
                 actor: SystemActor.actor(),
                 load: [video: [:video_tracks, :audio_tracks, :text_tracks]]
               )

      assert updated_media.id == original_media_id
      assert updated_media.path == original_path
      assert updated_media.video.id == original_video_id

      refute VideoTrack
             |> Ash.Query.filter(id == ^old_track_id)
             |> Ash.exists?(authorize?: false)
    end

    test "forbids non-system actors" do
      user = generate(user())
      movie = seed_movie()

      media = create_video!(video_input("tmp/forbid-update.mkv", movie), actor: SystemActor.actor())

      update_video(media, %{video: %{movie_id: movie.id, video_tracks: []}}, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "assign_last_successful_import/*" do
    test "sets the last successful Media Import for a Media" do
      movie = seed_movie()
      media = create_video!(video_input("tmp/assign.mkv", movie), actor: SystemActor.actor())
      run = seed_import_run()

      assert %Media{last_successful_media_import_id: run_id} =
               assign_last_successful_import!(
                 media,
                 %{last_successful_media_import_id: run.id},
                 actor: SystemActor.actor()
               )

      assert run_id == run.id
    end

    test "forbids non-system actors" do
      user = generate(user())
      movie = seed_movie()
      media = create_video!(video_input("tmp/forbid-assign.mkv", movie), actor: SystemActor.actor())
      run = seed_import_run()

      assign_last_successful_import(
        media,
        %{last_successful_media_import_id: run.id},
        actor: user
      )
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "destroy_media/*" do
    test "destroys media with its concrete media and track details" do
      movie = seed_movie()

      media =
        create_video!(video_input("tmp/destroy-media.mkv", movie),
          actor: SystemActor.actor(),
          load: [video: [:video_tracks, :audio_tracks, :text_tracks]]
        )

      video_track_id = media.video.video_tracks |> List.first() |> Map.fetch!(:id)
      audio_track_id = media.video.audio_tracks |> List.first() |> Map.fetch!(:id)
      text_track_id = media.video.text_tracks |> List.first() |> Map.fetch!(:id)

      assert :ok = destroy_media!(media, actor: SystemActor.actor())

      refute Media
             |> Ash.Query.filter(id == ^media.id)
             |> Ash.exists?(authorize?: false)

      refute Video
             |> Ash.Query.filter(id == ^media.id)
             |> Ash.exists?(authorize?: false)

      refute VideoTrack
             |> Ash.Query.filter(id == ^video_track_id)
             |> Ash.exists?(authorize?: false)

      refute AudioTrack
             |> Ash.Query.filter(id == ^audio_track_id)
             |> Ash.exists?(authorize?: false)

      refute TextTrack
             |> Ash.Query.filter(id == ^text_track_id)
             |> Ash.exists?(authorize?: false)
    end
  end

  defp video_input(path, %Movie{} = movie) do
    video_input(path, %{movie_id: movie.id})
  end

  defp video_input(path, %TvShowEpisode{} = tv_show_episode) do
    video_input(path, %{tv_show_episode_id: tv_show_episode.id})
  end

  defp video_input(path, attachment) do
    %{
      path: path,
      video:
        Map.merge(attachment, %{
          video_tracks: [
            %{
              stream_index: 0,
              codec: "h264",
              width: 1920,
              height: 1080
            }
          ],
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
            %{
              stream_index: 2,
              codec: "subrip",
              language: "eng"
            }
          ]
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

  defp seed_import_run do
    config =
      Ash.Seed.seed!(ImportConfiguration, %{
        source_type: :filesystem,
        content_type: :movie,
        media_type: :video,
        filesystem_path: "tmp/media-imports/#{System.unique_integer([:positive])}"
      })

    Ash.Seed.seed!(ImportRun, %{
      configuration_id: config.id,
      status: :pending,
      refresh_metadata?: false,
      triggered_manually?: true,
      configuration_snapshot: %{"id" => config.id}
    })
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
