defmodule WatchClub.Repo.Migrations.RenameMediaSourceAndMediaImport do
  @moduledoc """
  Renames the `media_import_configurations` table to `media_sources` and the
  `media_import_runs` table to `media_imports`, with matching column, index,
  and FK constraint renames.

  Pure in-place `ALTER TABLE ... RENAME` — no data move, no rebuild. The FK
  on `media.last_successful_media_import_id` follows the renamed table via
  its OID, so its constraint definition is left untouched.

  Pre-launch DB: any Oban jobs in `oban_jobs` referencing the previous worker
  name `WatchClub.Media.Workers.ExecuteImportRun` will not be discovered by
  the renamed worker `WatchClub.Media.Workers.ExecuteMediaImport`. Drain the
  `:media_imports` queue before deploying this migration.
  """

  use Ecto.Migration

  def up do
    # media_import_runs → media_imports
    rename table(:media_import_runs), to: table(:media_imports)

    rename table(:media_imports), :configuration_snapshot, to: :media_source_snapshot
    rename table(:media_imports), :configuration_id, to: :media_source_id

    execute """
    ALTER TABLE media_imports
      RENAME CONSTRAINT media_import_runs_configuration_id_fkey
      TO media_imports_media_source_id_fkey
    """

    execute """
    ALTER INDEX media_import_runs_one_processing_per_configuration_index
      RENAME TO media_imports_one_processing_per_media_source_index
    """

    # media_import_configurations → media_sources
    rename table(:media_import_configurations), to: table(:media_sources)
  end

  def down do
    rename table(:media_sources), to: table(:media_import_configurations)

    execute """
    ALTER INDEX media_imports_one_processing_per_media_source_index
      RENAME TO media_import_runs_one_processing_per_configuration_index
    """

    execute """
    ALTER TABLE media_imports
      RENAME CONSTRAINT media_imports_media_source_id_fkey
      TO media_import_runs_configuration_id_fkey
    """

    rename table(:media_imports), :media_source_id, to: :configuration_id
    rename table(:media_imports), :media_source_snapshot, to: :configuration_snapshot

    rename table(:media_imports), to: table(:media_import_runs)
  end
end
