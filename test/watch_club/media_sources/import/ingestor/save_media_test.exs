defmodule WatchClub.MediaSources.Import.Ingestor.SaveMediaTest do
  use WatchClub.DataCase, async: false

  alias WatchClub.Contents.{Content, Movie, TvShow, TvShowEpisode}
  alias WatchClub.MediaCatalog.{Media, Part, Video, VideoTrack}
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.{MatchResult, MediaStructure}
  alias WatchClub.MediaSources.Import.Ingestor.SaveMedia

  require Ash.Query

  describe "apply/1 —movie" do
    test "persists a Media + Video attached to the movie with the probed structure" do
      movie = seed_movie()

      candidate = %Candidate{
        media_source_id: default_media_source_id(),
        path: "tmp/star-wars.mkv",
        media_type: :movie,
        match_result: %MatchResult{result: :success, matched_id: movie.id},
        media_structure: sample_video_structure()
      }

      assert %Media{} = SaveMedia.apply(candidate)

      assert %Media{
               type: :movie,
               path: normalized_path,
               video: %Video{
                 parts: [%Part{movie_id: movie_id, number: 1}],
                 container: "matroska",
                 video_tracks: [%{codec: "h264"}],
                 audio_tracks: [_],
                 text_tracks: [_]
               }
             } = load_media!(candidate.path)

      assert movie_id == movie.id
      assert normalized_path == Path.expand("tmp/star-wars.mkv")
    end
  end

  describe "apply/1 —tv_show_episode" do
    test "persists a Media + Video attached to the TV show episode" do
      episode = seed_tv_show_episode()

      candidate = %Candidate{
        media_source_id: default_media_source_id(),
        path: "tmp/friends-s01e01.mkv",
        media_type: :tv_show_episode,
        match_result: %MatchResult{result: :success, matched_id: episode.id},
        media_structure: sample_video_structure()
      }

      assert %Media{} = SaveMedia.apply(candidate)

      assert %Media{
               type: :tv_show_episode,
               video: %Video{parts: [%Part{tv_show_episode_id: tv_show_episode_id}]}
             } = load_media!(candidate.path)

      assert tv_show_episode_id == episode.id
    end
  end

  describe "apply/1 —unmatched" do
    test "persists Media + unattached Video on a movie run when matched_id is nil" do
      candidate = %Candidate{
        media_source_id: default_media_source_id(),
        path: "tmp/unmatched-movie.mkv",
        media_type: :movie,
        match_result: %MatchResult{result: :not_matched, matched_id: nil},
        media_structure: sample_video_structure()
      }

      assert %Media{} = SaveMedia.apply(candidate)

      assert %Media{
               type: :movie,
               video: %Video{
                 parts: [],
                 container: "matroska",
                 video_tracks: [%{codec: "h264"}],
                 audio_tracks: [_],
                 text_tracks: [_]
               }
             } = load_media!(candidate.path)
    end

    test "persists Media + unattached Video on a tv_show_episode run when matched_id is nil" do
      candidate = %Candidate{
        media_source_id: default_media_source_id(),
        path: "tmp/unmatched-episode.mkv",
        media_type: :tv_show_episode,
        match_result: %MatchResult{result: :not_matched, matched_id: nil},
        media_structure: sample_video_structure()
      }

      assert %Media{} = SaveMedia.apply(candidate)

      assert %Media{
               type: :tv_show_episode,
               video: %Video{parts: []}
             } = load_media!(candidate.path)
    end
  end

  describe "apply/1 —refresh" do
    test "replaces the existing Video and tracks when the path already has a Media" do
      movie = seed_movie()
      path = "tmp/refresh-save.mkv"

      candidate_original = %Candidate{
        media_source_id: default_media_source_id(),
        path: path,
        media_type: :movie,
        match_result: %MatchResult{result: :success, matched_id: movie.id},
        media_structure: sample_video_structure()
      }

      assert %Media{} = SaveMedia.apply(candidate_original)
      original = load_media!(path)
      original_track_id = hd(original.video.video_tracks).id

      candidate_refresh = %Candidate{
        media_source_id: default_media_source_id(),
        path: path,
        media_type: :movie,
        match_result: %MatchResult{result: :success, matched_id: movie.id},
        media_structure: %{
          sample_video_structure()
          | video_tracks: [%{stream_index: 0, codec: "av1", width: 3840, height: 2160}],
            audio_tracks: [],
            text_tracks: []
        }
      }

      assert %Media{} = SaveMedia.apply(candidate_refresh)

      refreshed = load_media!(path)

      assert refreshed.id == original.id
      assert refreshed.video.id == original.video.id
      assert [%{codec: "av1"}] = refreshed.video.video_tracks

      refute VideoTrack
             |> Ash.Query.filter(id == ^original_track_id)
             |> Ash.exists?(authorize?: false)
    end
  end

  defp sample_video_structure do
    %MediaStructure{
      file_fingerprint: "fingerprint",
      container: "matroska",
      duration_seconds: 100.0,
      bit_rate: 5_000_000,
      video_tracks: [%{stream_index: 0, codec: "h264", width: 1920, height: 1080}],
      audio_tracks: [
        %{stream_index: 1, codec: "aac", language: "eng", channels: 2, default?: true}
      ],
      text_tracks: [%{stream_index: 2, codec: "subrip", language: "eng"}]
    }
  end

  defp load_media!(path) do
    Media
    |> Ash.Query.filter(path == ^Path.expand(path))
    |> Ash.Query.load(video: [:parts, :video_tracks, :audio_tracks, :text_tracks])
    |> Ash.read_one!(authorize?: false)
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
