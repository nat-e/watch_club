defmodule WatchClub.Media.ImportRunTest do
  use WatchClub.DataCase, async: false

  import Mox
  import WatchClub.Media

  alias WatchClub.Media.{ImportPipelineMock, ImportRun}

  setup :set_mox_global
  setup :verify_on_exit!

  describe "start_import_run/*" do
    test "completes the run when the pipeline succeeds" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))

      stub(ImportPipelineMock, :import_medias, fn _run -> :ok end)

      run = start_import_run!(configuration.id, actor: admin)

      Oban.drain_queue(queue: :media_imports)

      assert %ImportRun{status: :completed} = get_import_run_by_id!(run.id, actor: admin)
    end

    test "fails the run when the pipeline returns an error" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))

      stub(ImportPipelineMock, :import_medias, fn _run -> {:error, :boom} end)

      run = start_import_run!(configuration.id, actor: admin)

      Oban.drain_queue(queue: :media_imports)

      assert %ImportRun{status: :failed} = get_import_run_by_id!(run.id, actor: admin)
    end

    test "rejects a new run while one is already processing for the same configuration" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))

      start_import_run!(configuration.id, actor: admin)

      start_import_run(configuration.id, actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :configuration_id} -> true
        _ -> false
      end)
    end

    test "rejects non-admin actors" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(import_configuration(actor: admin))

      start_import_run(configuration.id, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "rejects an unknown configuration id" do
      admin = generate(administrator())

      start_import_run(Ash.UUIDv7.generate(), actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Query.NotFound{resource: WatchClub.Media.ImportConfiguration} -> true
        _ -> false
      end)
    end
  end

  describe "list_import_runs/*" do
    test "lists runs for an administrator" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))
      run = start_import_run!(configuration.id, actor: admin)

      assert [%ImportRun{id: id}] = list_import_runs!(actor: admin)
      assert id == run.id
    end

    test "rejects non-admin actors" do
      user = generate(user())

      list_import_runs(actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end
end
