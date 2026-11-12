defmodule WatchClub.MediaSources.Import.Workers.CandidateIngestorTest do
  use WatchClub.DataCase, async: false

  import Mox

  alias WatchClub.Contents.{Content, Movie}
  alias WatchClub.Ffmpeg.{ProbeMock, Trickplay}
  alias WatchClub.Markers.Workers.DetectMarkers
  alias WatchClub.MediaCatalog.{Media, Part, Video}
  alias WatchClub.MediaCatalog.Workers.GenerateTrickplay
  alias WatchClub.MediaSources.Import
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.MovieIdentity
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor

  require Ash.Query

  setup :verify_on_exit!

  describe "new_job/2" do
    test "enqueues a webhook candidate at high priority with no media_import_id" do
      media_source = generate(radarr_media_source())

      candidate = %Candidate{
        path: "/data/movies/x.mkv",
        media_type: :movie,
        identity: %MovieIdentity{tmdb_id: 11}
      }

      assert {:ok, _job} = Oban.insert(CandidateIngestor.new_job(media_source.servarr, candidate))

      assert_enqueued(
        worker: CandidateIngestor,
        priority: 0,
        args: %{media_source_id: media_source.id, path: "/data/movies/x.mkv"}
      )
    end

    test "enqueues a scan candidate at lower priority, tagged with the import" do
      import_id = Ash.UUIDv7.generate()

      candidate = %Candidate{
        path: "/data/movies/y.mkv",
        media_type: :movie,
        identity: %MovieIdentity{tmdb_id: 11}
      }

      media_source_id = Ash.UUIDv7.generate()

      assert {:ok, _job} =
               Oban.insert(
                 CandidateIngestor.new_job(
                   %Import{id: import_id, media_source_id: media_source_id},
                   candidate
                 )
               )

      assert_enqueued(
        worker: CandidateIngestor,
        priority: 1,
        args: %{media_import_id: import_id, media_source_id: media_source_id}
      )
    end
  end

  describe "perform/1 — no Media Import" do
    setup do
      ref = :telemetry_test.attach_event_handlers(self(), [[:watch_club, :media_ingest, :stop]])
      on_exit(fn -> :telemetry.detach(ref) end)
      %{telemetry_ref: ref}
    end

    test "ingests a present file into a Media attached to the matched movie", %{
      telemetry_ref: ref
    } do
      movie = seed_movie(tmdb_id: 11)
      stub(ProbeMock, :probe, fn _path -> {:ok, fixture("video_friends_s01e01")} end)

      path = Path.join(System.tmp_dir!(), "candidate-#{unique()}.mkv")
      File.write!(path, "stub")
      on_exit(fn -> File.rm(path) end)

      candidate = %Candidate{
        media_source_id: default_media_source_id(),
        path: path,
        media_type: :movie,
        identity: %MovieIdentity{tmdb_id: 11}
      }

      assert :ok = perform_job(CandidateIngestor, Candidate.to_map(candidate))

      assert %Media{type: :movie, video: %Video{parts: [%Part{movie_id: movie_id}]}} =
               load_media!(path)

      assert movie_id == movie.id

      assert_received {[:watch_club, :media_ingest, :stop], ^ref, %{duration: _},
                       %{media_type: :movie, trigger: :webhook, outcome: :matched, reason: nil}}
    end

    test "saves a file no Content matches as Unmatched Media", %{telemetry_ref: ref} do
      stub(ProbeMock, :probe, fn _path -> {:ok, fixture("video_friends_s01e01")} end)
      path = tmp_file!()

      candidate = %Candidate{
        media_source_id: default_media_source_id(),
        path: path,
        media_type: :movie,
        identity: %MovieIdentity{}
      }

      assert :ok = perform_job(CandidateIngestor, Candidate.to_map(candidate))

      assert %Media{content_id: nil, video: %Video{parts: []}} = load_media!(path)

      assert_received {[:watch_club, :media_ingest, :stop], ^ref, _measurements,
                       %{outcome: :unmatched, reason: :content_not_found}}
    end

    test "saves no Media for a file ffprobe can't read", %{telemetry_ref: ref} do
      stub(ProbeMock, :probe, fn _path -> {:error, "ffprobe exited with 1"} end)
      path = tmp_file!()

      candidate = %Candidate{
        media_source_id: default_media_source_id(),
        path: path,
        media_type: :movie,
        identity: %MovieIdentity{tmdb_id: 11}
      }

      assert :ok = perform_job(CandidateIngestor, Candidate.to_map(candidate))

      assert load_media!(path) == nil

      assert_received {[:watch_club, :media_ingest, :stop], ^ref, _measurements,
                       %{outcome: :unreadable, reason: nil}}
    end
  end

  describe "perform/1 — file already imported" do
    setup do
      seed_movie(tmdb_id: 11)
      stub(ProbeMock, :probe, fn _path -> {:ok, fixture("video_friends_s01e01")} end)

      path = Path.join(System.tmp_dir!(), "candidate-#{unique()}.mkv")
      File.write!(path, "stub")
      on_exit(fn -> File.rm(path) end)

      candidate = %Candidate{
        media_source_id: default_media_source_id(),
        path: path,
        media_type: :movie,
        identity: %MovieIdentity{tmdb_id: 11}
      }

      :ok = perform_job(CandidateIngestor, Candidate.to_map(candidate))
      %Media{id: id} = load_media!(path)

      # As GenerateTrickplay leaves them
      dir = Trickplay.dir(id)
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "meta.json"), "{}")
      on_exit(fn -> File.rm_rf!(dir) end)

      Oban.cancel_all_jobs(Oban.Job)
      %{candidate: candidate, media_id: id}
    end

    test "keeps the Scrubbing Thumbnails and Markers of an unchanged file",
         %{candidate: candidate} do
      assert :ok = perform_job(CandidateIngestor, Candidate.to_map(candidate))

      refute_enqueued(worker: GenerateTrickplay)
      refute_enqueued(worker: DetectMarkers)
    end

    test "regenerates the Scrubbing Thumbnails and Markers of an unchanged file when asked",
         %{candidate: candidate, media_id: media_id} do
      candidate = %{candidate | regenerate_thumbnails_and_markers?: true}

      assert :ok = perform_job(CandidateIngestor, Candidate.to_map(candidate))

      assert_enqueued(worker: GenerateTrickplay, args: %{video_id: media_id})
      assert_enqueued(worker: DetectMarkers)
    end
  end

  defp unique, do: System.unique_integer([:positive])

  defp tmp_file! do
    path = Path.join(System.tmp_dir!(), "candidate-#{unique()}.mkv")
    File.write!(path, "stub")
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp fixture(name) do
    [__DIR__, "../../../../support/fixtures/ffprobe", "#{name}.json"]
    |> Path.join()
    |> File.read!()
    |> Jason.decode!()
  end

  defp load_media!(path) do
    Media
    |> Ash.Query.filter(path == ^Path.expand(path))
    |> Ash.Query.load(video: [:parts, :video_tracks, :audio_tracks, :text_tracks])
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
