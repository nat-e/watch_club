defmodule WatchClub.Media.MediaImportTest do
  use WatchClub.DataCase, async: false

  import Mox
  import WatchClub.Media

  alias WatchClub.Media.{ImportPipelineMock, MediaImport}

  setup :set_mox_global
  setup :verify_on_exit!

  describe "start_media_import/*" do
    test "completes the Media Import when the pipeline succeeds" do
      admin = generate(administrator())
      media_source = generate(media_source(actor: admin))

      stub(ImportPipelineMock, :scan, fn _media_import -> {:ok, []} end)

      media_import = start_media_import!(media_source.id, actor: admin)

      Oban.drain_queue(queue: :scan_media_sources)
      Oban.drain_queue(queue: :monitor_media_imports, with_scheduled: true)

      assert %MediaImport{status: :completed} =
               get_media_import_by_id!(media_import.id, actor: admin)
    end

    test "fails the Media Import when the pipeline returns an error" do
      admin = generate(administrator())
      media_source = generate(media_source(actor: admin))

      stub(ImportPipelineMock, :scan, fn _media_import -> {:error, :boom} end)

      media_import = start_media_import!(media_source.id, actor: admin)

      Oban.drain_queue(queue: :scan_media_sources)

      assert %MediaImport{status: :failed} =
               get_media_import_by_id!(media_import.id, actor: admin)
    end

    test "fails the Media Import when the pipeline raises" do
      admin = generate(administrator())
      media_source = generate(media_source(actor: admin))

      stub(ImportPipelineMock, :scan, fn _media_import -> raise "boom" end)

      media_import = start_media_import!(media_source.id, actor: admin)

      Oban.drain_queue(queue: :scan_media_sources)

      assert %MediaImport{status: :failed} =
               get_media_import_by_id!(media_import.id, actor: admin)
    end

    test "rejects a new Media Import while one is already processing for the same Media Source" do
      admin = generate(administrator())
      media_source = generate(media_source(actor: admin))

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
      media_source = generate(media_source(actor: admin))

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

  describe "list_media_imports/*" do
    test "lists Media Imports for an administrator" do
      admin = generate(administrator())
      media_source = generate(media_source(actor: admin))
      media_import = start_media_import!(media_source.id, actor: admin)

      assert [%MediaImport{id: id}] = list_media_imports!(actor: admin)
      assert id == media_import.id
    end

    test "rejects non-admin actors" do
      user = generate(user())

      list_media_imports(actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end
end
