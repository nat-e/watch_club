defmodule WatchClub.Media.ImportRunTest do
  use WatchClub.DataCase

  import WatchClub.Media

  alias WatchClub.Media.{ImportResult, ImportRun}
  alias WatchClub.SystemActor

  describe "start_import_run/*" do
    test "creates a Pending Media Import with a configuration snapshot and schedules the run" do
      admin = generate(administrator())

      configuration =
        generate(
          import_configuration(
            actor: admin,
            content_type: :book,
            media_type: :ebook
          )
        )

      run = start_import_run!(configuration.id, actor: admin)

      assert %ImportRun{
               status: :pending,
               configuration_id: configuration_id,
               refresh_metadata?: false,
               triggered_manually?: true,
               configuration_snapshot: snapshot
             } = run

      assert configuration_id == configuration.id

      assert snapshot == %{
               "id" => configuration.id,
               "name" => "Book Ebook Filesystem: #{configuration.filesystem_path}",
               "source_type" => "filesystem",
               "content_type" => "book",
               "media_type" => "ebook",
               "filesystem_path" => configuration.filesystem_path
             }

      assert_triggered(run, :run, queue: :media_imports)
    end

    test "can refresh metadata for manually triggered imports" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))

      assert %ImportRun{refresh_metadata?: true} =
               start_import_run!(configuration.id, %{refresh_metadata?: true}, actor: admin)
    end

    test "creates a Pending Media Import for a disabled Media Import Configuration" do
      admin = generate(administrator())
      configuration = generate(import_configuration(disabled?: true))

      assert %ImportRun{status: :pending} =
               start_import_run!(configuration.id, actor: admin)
    end

    test "rejects attempts to mark manually triggered imports as scheduled" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))

      start_import_run(configuration.id, %{triggered_manually?: false}, actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Invalid.NoSuchInput{input: :triggered_manually?} -> true
        _ -> false
      end)
    end

    test "allows multiple Pending Media Imports for one configuration" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))

      assert %ImportRun{status: :pending} =
               start_import_run!(configuration.id, actor: admin)

      assert %ImportRun{status: :pending} =
               start_import_run!(configuration.id, actor: admin)
    end

    test "background processing completes the Media Import" do
      admin = generate(administrator())

      configuration =
        generate(import_configuration(actor: admin, filesystem_path: empty_import_directory!()))

      run = start_import_run!(configuration.id, actor: admin)

      Oban.drain_queue(queue: :media_imports)

      assert %ImportRun{status: :completed} =
               get_import_run_by_id!(run.id, actor: admin)
    end

    test "background processing completes queued Media Imports for one configuration" do
      admin = generate(administrator())

      configuration =
        generate(import_configuration(actor: admin, filesystem_path: empty_import_directory!()))

      first_run = start_import_run!(configuration.id, actor: admin)
      second_run = start_import_run!(configuration.id, actor: admin)

      Oban.drain_queue(queue: :media_imports)

      assert %ImportRun{status: :completed} =
               get_import_run_by_id!(first_run.id, actor: admin)

      assert %ImportRun{status: :completed} =
               get_import_run_by_id!(second_run.id, actor: admin)
    end

    test "background processing uses the Media Import Configuration snapshot" do
      admin = generate(administrator())

      configuration =
        generate(import_configuration(actor: admin, filesystem_path: empty_import_directory!()))

      run = start_import_run!(configuration.id, actor: admin)

      update_import_configuration!(
        configuration,
        %{
          filesystem_path:
            Path.join(
              System.tmp_dir!(),
              "watch-club-missing-import-path-#{System.unique_integer([:positive])}"
            )
        },
        actor: admin
      )

      Oban.drain_queue(queue: :media_imports)

      assert %ImportRun{status: :completed} =
               get_import_run_by_id!(run.id, actor: admin)
    end

    test "background processing records No Match results for unmatched candidate files" do
      admin = generate(administrator())
      directory = empty_import_directory!()
      file_path = Path.join(directory, "WatchClub Guide.pdf")
      File.write!(file_path, "not a real pdf")

      configuration =
        generate(
          import_configuration(
            actor: admin,
            content_type: :book,
            media_type: :ebook,
            filesystem_path: directory
          )
        )

      run = start_import_run!(configuration.id, actor: admin)

      Oban.drain_queue(queue: :media_imports)

      assert %ImportRun{status: :completed} =
               get_import_run_by_id!(run.id, actor: admin)

      assert [
               %ImportResult{
                 status: :no_match,
                 path: ^file_path,
                 message: "Could not confidently match file to Content or TV Show Episode",
                 metadata: %{
                   "content_type" => "book",
                   "media_type" => "ebook",
                   "relative_path" => "WatchClub Guide.pdf",
                   "existing_media_id" => nil
                 }
               }
             ] = import_results_for_run!(run.id, actor: admin)
    end

    test "only the Instance Administrator can trigger Media Imports" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(import_configuration(actor: admin))

      start_import_run(configuration.id, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  defp empty_import_directory! do
    path =
      Path.join(
        System.tmp_dir!(),
        "watch-club-media-import-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(path)
    on_exit(fn -> File.rm_rf!(path) end)

    path
  end

  describe "complete_import_run/*" do
    test "completes a Processing Media Import for the system actor" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))
      run = generate(import_run(configuration, status: :processing))

      assert %ImportRun{status: :completed} =
               complete_import_run!(run, actor: SystemActor.actor())
    end

    test "only the system actor can complete Media Imports" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))
      run = generate(import_run(configuration, status: :processing))

      complete_import_run(run, actor: admin)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "fail_import_run/*" do
    test "fails a Pending Media Import for the system actor" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))
      run = generate(import_run(configuration, status: :pending))

      assert %ImportRun{status: :failed} =
               fail_import_run!(run, actor: SystemActor.actor())
    end

    test "only the system actor can fail Media Imports" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))
      run = generate(import_run(configuration, status: :pending))

      fail_import_run(run, actor: admin)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "list_import_runs/*" do
    test "lists Media Imports for the Instance Administrator" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))
      run = start_import_run!(configuration.id, actor: admin)

      assert [%ImportRun{id: run_id}] = list_import_runs!(actor: admin)
      assert run_id == run.id
    end

    test "only the Instance Administrator can list Media Imports" do
      user = generate(user())

      list_import_runs(actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end
end
