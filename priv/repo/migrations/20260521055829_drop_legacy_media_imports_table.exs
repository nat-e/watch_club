defmodule WatchClub.Repo.Migrations.DropLegacyMediaImportsTable do
  use Ecto.Migration

  def up do
    drop table(:media_imports)
  end

  def down do
    raise Ecto.MigrationError, "Cannot rollback: media_imports table is permanently dropped"
  end
end
