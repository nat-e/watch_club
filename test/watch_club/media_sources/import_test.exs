defmodule WatchClub.MediaSources.ImportTest do
  use WatchClub.DataCase, async: false

  import Mox
  import WatchClub.MediaSources

  alias WatchClub.Ffmpeg.ProbeMock
  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.Markers.Workers.DetectMarkers
  alias WatchClub.MediaCatalog.Media
  alias WatchClub.MediaCatalog.Workers.GenerateTrickplay
  alias WatchClub.MediaSources.Import
  alias WatchClub.MediaSources.Import.{Candidate, FileStamp, ScannerMock}
  alias WatchClub.MediaSources.Import.Candidate.MovieIdentity
  alias WatchClub.MediaSources.Import.Scanner.Filesystem
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor
  alias WatchClub.SystemActor

  require Ash.Query

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

    test "processes the files without Media and those whose File Stamp changed" do
      %{admin: admin, media_source: media_source, paths: paths} = scanned_files()

      start_media_import!(media_source.id, actor: admin)
      Oban.drain_queue(queue: :media_source_scans)

      assert ingested_paths() == Enum.sort([paths.new, paths.changed])
    end

    test "processes a Video again when a subtitle file is added next to it" do
      %{admin: admin, media_source: media_source, paths: paths} = scanned_files()
      File.write!(String.replace_suffix(paths.unchanged, ".mkv", ".fr.srt"), "stub")

      start_media_import!(media_source.id, actor: admin)
      Oban.drain_queue(queue: :media_source_scans)

      assert paths.unchanged in ingested_paths()
    end

    test "processes the video files of a filesystem Media Source of Sports Events" do
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin, media_type: :sports_event))
      root = media_source.implementation.filesystem_path
      path = Path.join(root, "WRC - S2024E04 - WRC Croatia Rally - sportarr-ev-369605.mkv")
      File.mkdir_p!(root)
      File.write!(path, "stub")
      on_exit(fn -> File.rm_rf!(root) end)
      stub_with(ScannerMock, Filesystem)

      start_media_import!(media_source.id, actor: admin)
      Oban.drain_queue(queue: :media_source_scans)

      assert ingested_paths() == [path]
    end

    test "processes every file when it reads every file again" do
      %{admin: admin, media_source: media_source, paths: paths} = scanned_files()

      start_media_import!(media_source.id, %{read_every_file_again?: true}, actor: admin)
      Oban.drain_queue(queue: :media_source_scans)

      assert ingested_paths() == Enum.sort([paths.new, paths.unchanged, paths.changed])
    end

    test "stamps a Media saved without a File Stamp, without processing its file" do
      %{admin: admin, media_source: media_source, paths: paths} = scanned_files()

      media =
        generate(
          video_media(nil, media_source_id: media_source.id, path: paths.new, file_stamp: nil)
        )

      start_media_import!(media_source.id, actor: admin)
      Oban.drain_queue(queue: :media_source_scans)

      assert ingested_paths() == [paths.changed]

      assert Ash.reload!(media, authorize?: false).file_stamp ==
               FileStamp.read(paths.new, :movie)
    end

    test "removes the Media of a file the source no longer lists and that is gone from disk" do
      %{admin: admin, media_source: media_source, paths: paths} = scanned_files()
      gone = generate(video_media(nil, media_source_id: media_source.id))

      start_media_import!(media_source.id, actor: admin)
      Oban.drain_queue(queue: :media_source_scans)

      refute Media |> Ash.Query.filter(id == ^gone.id) |> Ash.exists?(authorize?: false)
      assert ingested_paths() == Enum.sort([paths.new, paths.changed])
    end

    test "keeps the Media of a file the source no longer lists while it's on disk" do
      %{admin: admin, media_source: media_source, paths: paths} = scanned_files()
      unlisted = Path.join(Path.dirname(paths.new), "unlisted.mkv")
      File.write!(unlisted, "stub")
      media = generate(video_media(nil, media_source_id: media_source.id, path: unlisted))

      start_media_import!(media_source.id, actor: admin)
      Oban.drain_queue(queue: :media_source_scans)

      assert Media |> Ash.Query.filter(id == ^media.id) |> Ash.exists?(authorize?: false)
    end

    test "keeps the Media of a listed file missing from disk as it is" do
      %{admin: admin, media_source: media_source, paths: paths} = scanned_files()
      missing = Path.join(Path.dirname(paths.new), "missing.mkv")

      media =
        generate(
          video_media(nil,
            media_source_id: media_source.id,
            path: missing,
            file_stamp: "stamp"
          )
        )

      stub(ScannerMock, :scan, fn _media_import -> [Candidate.new(missing, :movie)] end)

      start_media_import!(media_source.id, actor: admin)
      Oban.drain_queue(queue: :media_source_scans)

      assert ingested_paths() == []
      assert Media |> Ash.Query.filter(id == ^media.id) |> Ash.exists?(authorize?: false)
    end

    test "removes no Media when the source lists no file" do
      %{admin: admin, media_source: media_source} = scanned_files()
      media = generate(video_media(nil, media_source_id: media_source.id))
      stub(ScannerMock, :scan, fn _media_import -> [] end)

      start_media_import!(media_source.id, actor: admin)
      Oban.drain_queue(queue: :media_source_scans)

      assert Media |> Ash.Query.filter(id == ^media.id) |> Ash.exists?(authorize?: false)
    end

    test "regenerates the Scrubbing Thumbnails and Markers of every Video of its Media Source when asked" do
      %{admin: admin, media_source: media_source} = scanned_files()

      videos =
        Media
        |> Ash.Query.filter(media_source_id == ^media_source.id)
        |> Ash.read!(authorize?: false)

      start_media_import!(media_source.id, %{regenerate_thumbnails_and_markers?: true},
        actor: admin
      )

      Oban.drain_queue(queue: :media_source_scans)

      for video <- videos do
        assert_enqueued(worker: GenerateTrickplay, args: %{video_id: video.id})
      end

      [matched] = Enum.reject(videos, &is_nil(&1.content_id))
      assert_enqueued(worker: DetectMarkers, args: %{movie_id: matched.content_id})
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

      stub(ProbeMock, :keyframes, fn _path, _stream_index ->
        {:ok, [{0.0, 250_000}, {2.002, 180_000}]}
      end)

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

  describe "start_scheduled_media_imports/*" do
    test "starts a Media Import of the new and changed files of each Media Source" do
      admin = generate(administrator())

      media_source_ids =
        [generate(filesystem_media_source(actor: admin)).id] ++
          for flavor <- [:radarr, :sonarr, :sportarr],
              do: generate(radarr_media_source(actor: admin, flavor: flavor)).id

      start_scheduled_media_imports!(actor: SystemActor.actor())

      media_imports = list_media_imports!(actor: admin)

      assert Enum.sort(Enum.map(media_imports, & &1.media_source_id)) ==
               Enum.sort(media_source_ids)

      assert Enum.all?(
               media_imports,
               &match?(%Import{read_every_file_again?: false, triggered_manually?: false}, &1)
             )
    end

    test "skips a Media Source whose Media Import is processing" do
      admin = generate(administrator())
      media_source = generate(radarr_media_source(actor: admin))
      media_import = start_media_import!(media_source.id, actor: admin)

      start_scheduled_media_imports!(actor: SystemActor.actor())

      assert [%Import{id: id}] = list_media_imports!(actor: admin)
      assert id == media_import.id
    end

    test "deletes a scheduled Media Import that adds no Media" do
      admin = generate(administrator())
      generate(radarr_media_source(actor: admin))

      start_scheduled_media_imports!(actor: SystemActor.actor())
      Oban.drain_queue(queue: :media_source_scans)
      Oban.drain_queue(queue: :media_import_monitors, with_scheduled: true)

      assert list_media_imports!(actor: admin) == []
    end

    test "deletes a scheduled Media Import that fails without adding Media" do
      admin = generate(administrator())
      generate(radarr_media_source(actor: admin))
      stub_servarr(fn conn -> Plug.Conn.send_resp(conn, 401, "nope") end)

      start_scheduled_media_imports!(actor: SystemActor.actor())
      Oban.drain_queue(queue: :media_source_scans)
      Oban.drain_queue(queue: :media_import_monitors, with_scheduled: true)

      assert list_media_imports!(actor: admin) == []
    end

    test "keeps a scheduled Media Import that adds Media" do
      admin = generate(administrator())
      root = Path.expand("tmp/media-imports/scheduled")
      path = Path.join(root, "Star Wars (1977)/movie.mkv")
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, "stub")
      on_exit(fn -> File.rm_rf!(root) end)
      generate(radarr_media_source(actor: admin, root_folder_path: root))
      generate(movie(external_id: "11", metadata_refreshed_at: DateTime.utc_now()))

      stub_servarr(fn %Plug.Conn{request_path: "/api/v3/movie"} = conn ->
        Req.Test.json(conn, [
          %{
            "tmdbId" => 11,
            "title" => "Star Wars",
            "year" => 1977,
            "hasFile" => true,
            "qualityProfileId" => 1,
            "rootFolderPath" => root,
            "movieFile" => %{"path" => path}
          }
        ])
      end)

      stub(ProbeMock, :probe, fn _path -> {:ok, ffprobe_fixture("video_friends_s01e01")} end)

      stub(ProbeMock, :keyframes, fn _path, _stream_index ->
        {:ok, [{0.0, 250_000}, {2.002, 180_000}]}
      end)

      start_scheduled_media_imports!(actor: SystemActor.actor())
      Oban.drain_queue(queue: :media_source_scans)
      Oban.drain_queue(queue: :media_candidate_ingestions, with_scheduled: true)
      Oban.drain_queue(queue: :media_import_monitors, with_scheduled: true)

      assert [%Import{status: :completed, matched_file_count: 1}] =
               list_media_imports!(actor: admin)
    end

    test "rejects the Instance Administrator" do
      start_scheduled_media_imports(actor: generate(administrator()))
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  defp stub_servarr(plug) do
    previous = Application.get_env(:watch_club, :servarr_req_options)
    Application.put_env(:watch_club, :servarr_req_options, plug: {Req.Test, Client})
    on_exit(fn -> Application.put_env(:watch_club, :servarr_req_options, previous) end)
    Req.Test.stub(Client, plug)
  end

  # A Media Source whose scan finds a file without Media, a Media whose file hasn't changed and a
  # Media whose file changed since it was processed
  defp scanned_files do
    admin = generate(administrator())
    media_source = generate(filesystem_media_source(actor: admin))
    root = media_source.implementation.filesystem_path
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)

    paths = %{
      new: Path.expand("#{root}/new.mkv"),
      unchanged: Path.expand("#{root}/unchanged.mkv"),
      changed: Path.expand("#{root}/changed.mkv")
    }

    for path <- Map.values(paths), do: File.write!(path, "stub")

    generate(
      video_media(generate(movie()),
        media_source_id: media_source.id,
        path: paths.unchanged,
        file_stamp: FileStamp.read(paths.unchanged, :movie)
      )
    )

    generate(
      video_media(nil,
        media_source_id: media_source.id,
        path: paths.changed,
        file_stamp: "the stamp of the file it replaced"
      )
    )

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
