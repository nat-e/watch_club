defmodule WatchClub.Repo.Migrations.RadarrMediaSourceType do
  @moduledoc """
  Polymorphic Media Source decomposition. Adds:

    * `filesystem_media_sources` — owns `filesystem_path` for filesystem
      sources.
    * `radarr_media_sources` — owns connection details and request-side
      settings for radarr sources.

  Both child tables share their primary key with `media_sources` and
  cascade-delete with the parent.

  Backfills `filesystem_media_sources` from the existing
  `media_sources.filesystem_path` column, then drops the column from the
  parent.

  Reshapes `media_imports.media_source_snapshot` to nest type-specific
  config under the `config` key (matching
  `WatchClub.Media.MediaImport.Changes.SnapshotMediaSource`).
  """
  use Ecto.Migration

  def up do
    create table(:filesystem_media_sources, primary_key: false) do
      add :id,
          references(:media_sources, type: :uuid, on_delete: :delete_all, on_update: :update_all),
          primary_key: true,
          null: false

      add :filesystem_path, :text, null: false
    end

    create table(:radarr_media_sources, primary_key: false) do
      add :id,
          references(:media_sources, type: :uuid, on_delete: :delete_all, on_update: :update_all),
          primary_key: true,
          null: false

      add :base_url, :text, null: false
      add :api_key, :text, null: false
      add :quality_profile_id, :integer, null: false
      add :root_folder_path, :text, null: false
      add :local_root_folder_path, :text, null: true
    end

    execute """
    INSERT INTO filesystem_media_sources (id, filesystem_path)
    SELECT id, filesystem_path
    FROM media_sources
    WHERE source_type = 'filesystem'
    """

    alter table(:media_sources) do
      remove :filesystem_path
    end

    # Reshape existing media_imports.media_source_snapshot so its
    # type-specific keys live under "config". Existing rows are
    # filesystem-only, so the only legacy key is `filesystem_path`.
    execute """
    UPDATE media_imports
    SET media_source_snapshot = jsonb_set(
      media_source_snapshot - 'filesystem_path',
      '{config}',
      jsonb_build_object('filesystem_path', media_source_snapshot->>'filesystem_path')
    )
    WHERE media_source_snapshot ? 'filesystem_path'
    """
  end

  def down do
    execute """
    UPDATE media_imports
    SET media_source_snapshot =
      (media_source_snapshot - 'config')
      || jsonb_build_object('filesystem_path', media_source_snapshot->'config'->>'filesystem_path')
    WHERE media_source_snapshot ? 'config'
    """

    alter table(:media_sources) do
      add :filesystem_path, :text, null: true
    end

    execute """
    UPDATE media_sources ms
    SET filesystem_path = fms.filesystem_path
    FROM filesystem_media_sources fms
    WHERE ms.id = fms.id
    """

    drop table(:radarr_media_sources)
    drop table(:filesystem_media_sources)
  end
end
