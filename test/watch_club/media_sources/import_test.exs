defmodule WatchClub.MediaSources.ImportTest do
  use WatchClub.DataCase, async: false

  import Mox
  import WatchClub.MediaSources

  alias WatchClub.Ffmpeg.ProbeMock
  alias WatchClub.MediaSources.Import
  alias WatchClub.MediaSources.Import.{Candidate, ScannerMock}
  alias WatchClub.MediaSources.Import.Candidate.MovieIdentity
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor
  alias WatchClub.SystemActor

  setup :set_mox_global
  setup :verify_on_exit!

  describe "start_media_import/*" do
    test "completes the Media Import when the pipeline succeeds" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:watch_club, :media_import, :finish]])
      on_exit(fn -> :telemetry.detach(ref) end)
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin))

      stub(ScannerMock, :scan, fn _media_import -> [] end)

      media_import = start_media_import!(media_source.id, actor: admin)

      Oban.drain_queue(queue: :media_source_scans)
      Oban.drain_queue(queue: :media_import_monitors, with_scheduled: true)

      assert %Import{status: :completed} =
               get_media_import_by_id!(media_import.id, actor: admin)

      assert_received {[:watch_club, :media_import, :finish], ^ref, %{duration: duration},
                       %{status: :completed}}

      assert duration >= 0
    end

    test "fails the Media Import when the pipeline raises" do
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin))

      stub(ScannerMock, :scan, fn _media_import -> raise "boom" end)

      media_import = start_media_import!(media_source.id, actor: admin)

      Oban.drain_queue(queue: :media_source_scans)
      Oban.drain_queue(queue: :media_import_monitors, with_scheduled: true)

      assert %Import{status: :failed} =
               get_media_import_by_id!(media_import.id, actor: admin)
    end

    test "processes only the files without Media by default" do
      %{admin: admin, media_source: media_source, paths: paths} = scanned_files()

      start_media_import!(media_source.id, actor: admin)
      Oban.drain_queue(queue: :media_source_scans)

      assert ingested_paths() == [paths.new]
    end

    test "processes the files without Media and the Unmatched Media with :new_and_unmatched" do
      %{admin: admin, media_source: media_source, paths: paths} = scanned_files()

      start_media_import!(media_source.id, %{files_to_process: :new_and_unmatched}, actor: admin)
      Oban.drain_queue(queue: :media_source_scans)

      assert ingested_paths() == Enum.sort([paths.new, paths.unmatched])
    end

    test "processes every file with :all" do
      %{admin: admin, media_source: media_source, paths: paths} = scanned_files()

      start_media_import!(media_source.id, %{files_to_process: :all}, actor: admin)
      Oban.drain_queue(queue: :media_source_scans)

      assert ingested_paths() == Enum.sort(Map.values(paths))
    end

    test "has each file it processes regenerate its Scrubbing Thumbnails and Markers when asked" do
      %{admin: admin, media_source: media_source, paths: paths} = scanned_files()

      start_media_import!(
        media_source.id,
        %{files_to_process: :all, regenerate_thumbnails_and_markers?: true},
        actor: admin
      )

      Oban.drain_queue(queue: :media_source_scans)

      for path <- Map.values(paths) do
        assert_enqueued(
          worker: CandidateIngestor,
          args: %{path: path, regenerate_thumbnails_and_markers?: true}
        )
      end
    end

    test "counts the files it processes by outcome" do
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin))
      generate(movie(external_id: "11", metadata_refreshed_at: DateTime.utc_now()))

      root = media_source.implementation.filesystem_path
      File.mkdir_p!(root)
      on_exit(fn -> File.rm_rf!(root) end)

      candidates =
        for {name, identity} <- [
              matched: %MovieIdentity{tmdb_id: 11},
              unmatched: %MovieIdentity{},
              unreadable: %MovieIdentity{},
              crashing: %MovieIdentity{}
            ] do
          path = Path.join(root, "#{name}.mkv")
          File.write!(path, "stub")
          %Candidate{path: path, media_type: :movie, identity: identity}
        end

      stub(ScannerMock, :scan, fn _media_import -> candidates end)

      stub(ProbeMock, :probe, fn path ->
        case Path.basename(path) do
          "unreadable.mkv" -> {:error, "ffprobe exited with 1"}
          "crashing.mkv" -> raise "boom"
          _readable -> {:ok, ffprobe_fixture("video_friends_s01e01")}
        end
      end)

      stub(ProbeMock, :keyframes, fn _path -> {:ok, [0.0, 2.002]} end)

      media_import = start_media_import!(media_source.id, actor: admin)

      Oban.drain_queue(queue: :media_source_scans)

      Oban.drain_queue(
        queue: :media_candidate_ingestions,
        with_scheduled: true,
        with_recursion: true
      )

      Oban.drain_queue(queue: :media_import_monitors, with_scheduled: true)

      assert %Import{
               status: :failed,
               file_count: 4,
               matched_file_count: 1,
               unmatched_file_count: 1,
               unreadable_file_count: 1,
               failed_file_count: 1
             } = get_media_import_by_id!(media_import.id, actor: admin)
    end

    test "rejects a new Media Import while one is already processing for the same Media Source" do
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin))

      start_media_import!(media_source.id, actor: admin)

      start_media_import(media_source.id, actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :media_source_id} -> true
        _ -> false
      end)
    end

    test "rejects non-admin actors" do
      admin = generate(administrator())
      user = generate(user())
      media_source = generate(filesystem_media_source(actor: admin))

      start_media_import(media_source.id, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "rejects an unknown Media Source id" do
      admin = generate(administrator())

      start_media_import(Ash.UUIDv7.generate(), actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :media_source_id} -> true
        _ -> false
      end)
    end
  end

  # A Media Source whose scan finds a new file, a matched Media and an Unmatched Media
  defp scanned_files do
    admin = generate(administrator())
    media_source = generate(filesystem_media_source(actor: admin))
    root = media_source.implementation.filesystem_path

    paths = %{
      new: "#{root}/new.mkv",
      matched: "#{root}/matched.mkv",
      unmatched: "#{root}/unmatched.mkv"
    }

    generate(
      video_media(generate(movie()), media_source_id: media_source.id, path: paths.matched)
    )

    generate(video_media(nil, media_source_id: media_source.id, path: paths.unmatched))

    stub(ScannerMock, :scan, fn _media_import ->
      Enum.map(Map.values(paths), &Candidate.new(&1, :movie))
    end)

    %{admin: admin, media_source: media_source, paths: paths}
  end

  defp ingested_paths do
    [worker: CandidateIngestor]
    |> all_enqueued()
    |> Enum.map(& &1.args["path"])
    |> Enum.sort()
  end

  describe "finish_media_import_scan/*" do
    test "records the files the scan found to process" do
      media_import = processing_media_import(generate(administrator()))

      assert %Import{file_count: 12} =
               finish_media_import_scan!(media_import, 12, actor: SystemActor.actor())
    end

    test "rejects the Instance Administrator" do
      admin = generate(administrator())

      admin
      |> processing_media_import()
      |> finish_media_import_scan(12, actor: admin)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "count_media_import_file/*" do
    test "adds the file to the count of its outcome" do
      media_import = processing_media_import(generate(administrator()))

      count_media_import_file!(media_import, :unmatched, actor: SystemActor.actor())

      assert %Import{matched_file_count: 1, unmatched_file_count: 1, unreadable_file_count: 0} =
               count_media_import_file!(media_import, :matched, actor: SystemActor.actor())
    end

    test "rejects the Instance Administrator" do
      admin = generate(administrator())

      admin
      |> processing_media_import()
      |> count_media_import_file(:matched, actor: admin)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  defp processing_media_import(admin) do
    media_source = generate(filesystem_media_source(actor: admin))
    start_media_import!(media_source.id, actor: admin)
  end

  defp ffprobe_fixture(name) do
    [__DIR__, "../../support/fixtures/ffprobe", "#{name}.json"]
    |> Path.join()
    |> File.read!()
    |> Jason.decode!()
  end

  describe "list_media_imports/*" do
    test "lists Media Imports for an administrator" do
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin))
      media_import = start_media_import!(media_source.id, actor: admin)

      assert [%Import{id: id}] = list_media_imports!(actor: admin)
      assert id == media_import.id
    end

    test "rejects non-admin actors" do
      user = generate(user())

      list_media_imports(actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end
end
