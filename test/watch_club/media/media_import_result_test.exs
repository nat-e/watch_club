defmodule WatchClub.Media.MediaImportResultTest do
  use WatchClub.DataCase

  import WatchClub.Media

  alias WatchClub.Media.MediaImportResult
  alias WatchClub.SystemActor

  describe "media_import_results_for_import/*" do
    test "lists Media Import Results for one Media Import newest first" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))

      first_import = generate(media_import(configuration))
      second_import = generate(media_import(configuration))
      older_inserted_at = ~U[2026-01-01 00:00:00Z]
      newer_inserted_at = ~U[2026-01-02 00:00:00Z]

      older_result =
        seed_media_import_result(first_import, :created, "older.mkv", older_inserted_at)

      newer_result =
        seed_media_import_result(first_import, :updated, "newer.mkv", newer_inserted_at)

      seed_media_import_result(second_import, :failed, "other.mkv")

      assert [
               %MediaImportResult{id: newer_result_id, status: :updated},
               %MediaImportResult{id: older_result_id, status: :created}
             ] = media_import_results_for_import!(first_import.id, actor: admin)

      assert newer_result_id == newer_result.id
      assert older_result_id == older_result.id
    end

    test "only the Instance Administrator can list Media Import Results" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(media_import_configuration(actor: admin))
      media_import = generate(media_import(configuration))

      media_import_results_for_import(media_import.id, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "create_media_import_result/*" do
    test "creates a Media Import Result for the system actor" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))
      media_import = generate(media_import(configuration))
      path = "tmp/import-results/system-created.mkv"

      assert %MediaImportResult{
               status: :failed,
               path: expanded_path,
               message: "ffprobe failed",
               metadata: %{"stage" => "probe"}
             } =
               create_media_import_result!(
                 %{
                   media_import_id: media_import.id,
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
      configuration = generate(media_import_configuration(actor: admin))
      media_import = generate(media_import(configuration))

      create_media_import_result(
        %{
          media_import_id: media_import.id,
          status: :failed,
          path: "tmp/import-results/user-created.mkv",
          metadata: %{}
        },
        actor: user
      )
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  defp seed_media_import_result(media_import, status, filename, inserted_at \\ DateTime.utc_now()) do
    Ash.Seed.seed!(MediaImportResult, %{
      media_import_id: media_import.id,
      status: status,
      path: Path.expand("tmp/import-results/#{filename}"),
      metadata: %{},
      inserted_at: inserted_at,
      updated_at: inserted_at
    })
  end
end
