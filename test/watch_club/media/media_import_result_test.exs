defmodule WatchClub.Media.MediaImportResultTest do
  use WatchClub.DataCase

  import WatchClub.Media

  alias WatchClub.Media.{MediaImport, MediaImportResult}

  describe "media_import_results_for_import/*" do
    test "lists Media Import Results for one Media Import newest first" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))

      first_import = seed_media_import(configuration)
      second_import = seed_media_import(configuration)
      older_inserted_at = ~U[2026-01-01 00:00:00Z]
      newer_inserted_at = ~U[2026-01-02 00:00:00Z]

      older_result =
        Ash.Seed.seed!(MediaImportResult, %{
          media_import_id: first_import.id,
          status: :created,
          path: Path.expand("tmp/import-results/older.mkv"),
          metadata: %{"container" => "matroska"},
          inserted_at: older_inserted_at,
          updated_at: older_inserted_at
        })

      newer_result =
        Ash.Seed.seed!(MediaImportResult, %{
          media_import_id: first_import.id,
          status: :updated,
          path: Path.expand("tmp/import-results/newer.mkv"),
          metadata: %{"container" => "matroska"},
          inserted_at: newer_inserted_at,
          updated_at: newer_inserted_at
        })

      Ash.Seed.seed!(MediaImportResult, %{
        media_import_id: second_import.id,
        status: :failed,
        path: Path.expand("tmp/import-results/other.mkv"),
        message: "Probe failed",
        metadata: %{}
      })

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
      media_import = seed_media_import(configuration)

      media_import_results_for_import(media_import.id, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  defp seed_media_import(configuration) do
    Ash.Seed.seed!(MediaImport, %{
      configuration_id: configuration.id,
      status: :pending,
      refresh_metadata?: false,
      triggered_manually?: true,
      configuration_snapshot: %{"id" => configuration.id}
    })
  end
end
