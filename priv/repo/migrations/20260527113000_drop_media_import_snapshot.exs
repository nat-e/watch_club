defmodule WatchClub.Repo.Migrations.DropMediaImportSnapshot do
  @moduledoc """
  Removes the snapshot mechanism on `media_imports`:

    * Drops the `media_source_snapshot` JSONB column. Imports now load
      the live `media_source` (with its `:implementation`) at run time.
    * Replaces the `:nilify` FK with `:cascade` so a `media_sources`
      delete also removes its `media_imports`.
    * Makes `media_source_id` `NOT NULL`. Any orphaned rows that came
      from the previous `nilify` behavior are deleted first.

  Reversible: the down direction restores the column (empty), reverts the
  FK to `:set_null`, and drops the NOT NULL constraint.
  """
  use Ecto.Migration

  def up do
    # Any imports whose source was deleted under the old :nilify policy
    # are orphaned — drop them before applying NOT NULL + cascade.
    execute "DELETE FROM media_imports WHERE media_source_id IS NULL"

    alter table(:media_imports) do
      remove :media_source_snapshot
    end

    drop constraint(:media_imports, "media_imports_media_source_id_fkey")

    alter table(:media_imports) do
      modify :media_source_id, :uuid, null: false
    end

    alter table(:media_imports) do
      modify :media_source_id,
             references(:media_sources,
               column: :id,
               name: "media_imports_media_source_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all,
               on_update: :update_all
             )
    end
  end

  def down do
    drop constraint(:media_imports, "media_imports_media_source_id_fkey")

    alter table(:media_imports) do
      modify :media_source_id, :uuid, null: true
    end

    alter table(:media_imports) do
      modify :media_source_id,
             references(:media_sources,
               column: :id,
               name: "media_imports_media_source_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :nilify_all,
               on_update: :update_all
             )

      add :media_source_snapshot, :map
    end
  end
end
