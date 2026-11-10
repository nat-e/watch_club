defmodule WatchClub.Repo.Migrations.ReplaceRefreshMetadataWithFilesToProcess do
  @moduledoc """
  Replaces a Media Import's Refresh Metadata with the files it processes: imports with Refresh
  Metadata on processed all files, the others only new ones.
  """

  use Ecto.Migration

  def up do
    alter table(:media_imports) do
      add :files_to_process, :text, null: false, default: "new"
    end

    execute("UPDATE media_imports SET files_to_process = 'all' WHERE refresh_metadata")

    alter table(:media_imports) do
      remove :refresh_metadata
    end
  end

  def down do
    alter table(:media_imports) do
      add :refresh_metadata, :boolean, null: false, default: false
    end

    execute("UPDATE media_imports SET refresh_metadata = files_to_process = 'all'")

    alter table(:media_imports) do
      remove :files_to_process
    end
  end
end
