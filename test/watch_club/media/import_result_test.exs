defmodule WatchClub.Media.ImportResultTest do
  use WatchClub.DataCase

  import WatchClub.Media

  alias WatchClub.Media.ImportResult
  alias WatchClub.SystemActor

  describe "import_results_for_run/*" do
    test "lists Media Import Results for one Media Import newest first" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))

      first_run = generate(import_run(configuration))
      second_run = generate(import_run(configuration))
      older_inserted_at = ~U[2026-01-01 00:00:00Z]
      newer_inserted_at = ~U[2026-01-02 00:00:00Z]

      older_result =
        seed_import_result(first_run, :created, "older.mkv", older_inserted_at)

      newer_result =
        seed_import_result(first_run, :updated, "newer.mkv", newer_inserted_at)

      seed_import_result(second_run, :failed, "other.mkv")

      assert [
               %ImportResult{id: newer_result_id, status: :updated},
               %ImportResult{id: older_result_id, status: :created}
             ] = import_results_for_run!(first_run.id, actor: admin)

      assert newer_result_id == newer_result.id
      assert older_result_id == older_result.id
    end

    test "only the Instance Administrator can list Media Import Results" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(import_configuration(actor: admin))
      run = generate(import_run(configuration))

      import_results_for_run(run.id, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "create_import_result/*" do
    test "creates a Media Import Result for the system actor" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))
      run = generate(import_run(configuration))
      path = "tmp/import-results/system-created.mkv"

      assert %ImportResult{
               status: :failed,
               path: expanded_path,
               message: "ffprobe failed",
               metadata: %{"stage" => "probe"}
             } =
               create_import_result!(
                 %{
                   media_import_id: run.id,
                   status: :failed,
                   path: path,
                   message: "ffprobe failed",
                   metadata: %{"stage" => "probe"}
                 },
                 actor: SystemActor.actor()
               )

      assert expanded_path == Path.expand(path)
    end

    test "rejects Media Import Result creation by regular users" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(import_configuration(actor: admin))
      run = generate(import_run(configuration))

      create_import_result(
        %{
          media_import_id: run.id,
          status: :failed,
          path: "tmp/import-results/user-created.mkv",
          metadata: %{}
        },
        actor: user
      )
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  defp seed_import_result(run, status, filename, inserted_at \\ DateTime.utc_now()) do
    Ash.Seed.seed!(ImportResult, %{
      media_import_id: run.id,
      status: status,
      path: Path.expand("tmp/import-results/#{filename}"),
      metadata: %{},
      inserted_at: inserted_at,
      updated_at: inserted_at
    })
  end
end
