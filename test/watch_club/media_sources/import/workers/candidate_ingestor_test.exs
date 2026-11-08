defmodule WatchClub.MediaSources.Import.Workers.CandidateIngestorTest do
  use WatchClub.DataCase, async: false

  import Mox

  alias WatchClub.Contents.{Content, Movie}
  alias WatchClub.Ffmpeg.ProbeMock
  alias WatchClub.MediaCatalog.{Media, Video}
  alias WatchClub.MediaSources.Import
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.MovieIdentity
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor

  require Ash.Query

  setup :verify_on_exit!

  describe "new_job/1 — webhook candidate" do
    test "enqueues at high priority with no media_import_id" do
      candidate = %Candidate{
        path: "/data/movies/x.mkv",
        media_type: :movie,
        identity: %MovieIdentity{tmdb_id: 11}
      }

      assert {:ok, _job} = Oban.insert(CandidateIngestor.new_job(candidate))

      assert_enqueued(worker: CandidateIngestor, priority: 0, args: %{path: "/data/movies/x.mkv"})
    end
  end

  describe "new_job/2 — scan candidate" do
    test "enqueues at lower priority, tagged with the import" do
      import_id = Ash.UUIDv7.generate()

      candidate = %Candidate{
        path: "/data/movies/y.mkv",
        media_type: :movie,
        identity: %MovieIdentity{tmdb_id: 11}
      }

      assert {:ok, _job} =
               Oban.insert(CandidateIngestor.new_job(%Import{id: import_id}, candidate))

      assert_enqueued(worker: CandidateIngestor, priority: 1, args: %{media_import_id: import_id})
    end
  end

  describe "perform/1 — no Media Import" do
    test "ingests a present file into a Media attached to the matched movie" do
      movie = seed_movie(tmdb_id: 11)
      stub(ProbeMock, :probe, fn _path -> {:ok, fixture("video_friends_s01e01")} end)

      path = Path.join(System.tmp_dir!(), "candidate-#{unique()}.mkv")
      File.write!(path, "stub")
      on_exit(fn -> File.rm(path) end)

      candidate = %Candidate{
        path: path,
        media_type: :movie,
        identity: %MovieIdentity{tmdb_id: 11}
      }

      assert :ok = perform_job(CandidateIngestor, Candidate.to_map(candidate))

      assert %Media{type: :movie, video: %Video{movie_id: movie_id}} = load_media!(path)
      assert movie_id == movie.id
    end
  end

  defp unique, do: System.unique_integer([:positive])

  defp fixture(name) do
    [__DIR__, "../../../../support/fixtures/ffprobe", "#{name}.json"]
    |> Path.join()
    |> File.read!()
    |> Jason.decode!()
  end

  defp load_media!(path) do
    Media
    |> Ash.Query.filter(path == ^Path.expand(path))
    |> Ash.Query.load(video: [:video_tracks, :audio_tracks, :text_tracks])
    |> Ash.read_one!(authorize?: false)
  end

  defp seed_movie(tmdb_id: tmdb_id) do
    unique = unique()

    content =
      Ash.Seed.seed!(Content, %{
        type: :movie,
        external_id_source: :tmdb,
        external_id: to_string(tmdb_id),
        original_title: "Movie #{unique}",
        original_language: "en",
        origin_country: "US",
        metadata_refreshed_at: DateTime.utc_now()
      })

    Ash.Seed.seed!(Movie, %{id: content.id})
  end
end
