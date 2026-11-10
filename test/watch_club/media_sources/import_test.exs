defmodule WatchClub.MediaSources.ImportTest do
  use WatchClub.DataCase, async: false

  import Mox
  import WatchClub.MediaSources

  alias WatchClub.MediaSources.Import
  alias WatchClub.MediaSources.Import.{Candidate, ScannerMock}
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor

  setup :set_mox_global
  setup :verify_on_exit!

  describe "start_media_import/*" do
    test "completes the Media Import when the pipeline succeeds" do
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin))

      stub(ScannerMock, :scan, fn _media_import -> [] end)

      media_import = start_media_import!(media_source.id, actor: admin)

      Oban.drain_queue(queue: :media_source_scans)
      Oban.drain_queue(queue: :media_import_monitors, with_scheduled: true)

      assert %Import{status: :completed} =
               get_media_import_by_id!(media_import.id, actor: admin)
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

    generate(video_media(generate(movie()), path: paths.matched))
    generate(video_media(nil, path: paths.unmatched))

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
