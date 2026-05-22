defmodule WatchClub.Media.ImportRunTest do
  use WatchClub.DataCase

  import WatchClub.Media

  alias WatchClub.Media.{ImportResult, ImportRun}

  require Ash.Query

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
                 media_id: nil,
                 message: "Book matching not yet implemented",
                 metadata: %{
                   "content_type" => "book",
                   "media_type" => "ebook",
                   "relative_path" => "WatchClub Guide.pdf",
                   "existing_media_id" => nil,
                   "content_id" => nil,
                   "content_action" => nil
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

    test "background processing creates Media for a matched movie candidate" do
      admin = generate(administrator())
      directory = empty_import_directory!()
      file_path = Path.join(directory, "Star Wars (1977) [tmdbid-11].mkv")
      write_tiny_mkv!(file_path)

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Req.Test.json(conn, tmdb_fixture("movie_details_11"))
      end)

      Req.Test.set_req_test_to_shared(self())

      configuration =
        generate(
          import_configuration(
            actor: admin,
            content_type: :movie,
            media_type: :video,
            filesystem_path: directory
          )
        )

      run = start_import_run!(configuration.id, actor: admin)
      run_id = run.id

      Oban.drain_queue(queue: :media_imports)

      assert %ImportRun{status: :completed} = get_import_run_by_id!(run.id, actor: admin)

      assert [
               %ImportResult{
                 status: :created,
                 path: ^file_path,
                 media_id: media_id,
                 metadata: %{
                   "content_type" => "movie",
                   "media_type" => "video",
                   "content_action" => "created"
                 }
               }
             ] = import_results_for_run!(run.id, actor: admin)

      assert is_binary(media_id)

      media =
        WatchClub.Media.Media
        |> Ash.Query.filter(id == ^media_id)
        |> Ash.Query.load(:video)
        |> Ash.read_one!(authorize?: false)

      assert %WatchClub.Media.Media{
               type: :video,
               last_successful_media_import_id: ^run_id,
               video: %WatchClub.Media.Video{movie_id: movie_id}
             } = media

      assert is_binary(movie_id)
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

  # Generates a 1-second silent black video with one h264 video track and one aac
  # audio track so `Ffmpeg.probe/1` returns the structure MatchContent needs.
  defp write_tiny_mkv!(path) do
    args = [
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      "-f",
      "lavfi",
      "-i",
      "color=c=black:s=64x64:d=1:r=24",
      "-f",
      "lavfi",
      "-i",
      "anullsrc=channel_layout=stereo:sample_rate=48000",
      "-shortest",
      "-c:v",
      "libx264",
      "-preset",
      "ultrafast",
      "-c:a",
      "aac",
      path
    ]

    {_, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
    :ok
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
