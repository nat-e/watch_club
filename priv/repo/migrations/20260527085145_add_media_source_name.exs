defmodule WatchClub.Repo.Migrations.AddMediaSourceName do
  @moduledoc """
  Adds the `name` column to `media_sources`. Backfills existing rows with the
  same value the application would now compute on create (`"Filesystem: <path>"`)
  before applying the NOT NULL constraint.
  """

  use Ecto.Migration

  def up do
    alter table(:media_sources) do
      add :name, :text
    end

    execute "UPDATE media_sources SET name = 'Filesystem: ' || filesystem_path WHERE name IS NULL"

    alter table(:media_sources) do
      modify :name, :text, null: false
    end
  end

  def down do
    alter table(:media_sources) do
      remove :name
    end
  end
end
