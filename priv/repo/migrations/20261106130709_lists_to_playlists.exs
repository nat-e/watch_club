defmodule WatchClub.Repo.Migrations.ListsToPlaylists do
  @moduledoc """
  Turns lists into Playlists, keeping their Content, and adds Playlist Access to share them.

  Generated with `mix ash.codegen`, then reordered so each table exists before it's referenced.
  """

  use Ecto.Migration

  def up do
    rename table(:lists), to: table(:playlists)

    drop constraint(:playlists, "lists_owner_id_fkey")

    alter table(:playlists) do
      modify :owner_id,
             references(:users,
               column: :id,
               name: "playlists_owner_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    rename table(:list_items), to: table(:playlist_items)
    rename table(:playlist_items), :list_id, to: :playlist_id
    rename table(:playlist_items), :created_at, to: :added_at

    drop_if_exists unique_index(:playlist_items, [:playlist_id, :content_id],
                     name: "list_items_list_and_content_index"
                   )

    create unique_index(:playlist_items, [:playlist_id, :content_id],
             name: "playlist_items_playlist_and_content_index"
           )

    drop constraint(:playlist_items, "list_items_list_id_fkey")
    drop constraint(:playlist_items, "list_items_content_id_fkey")

    alter table(:playlist_items) do
      modify :playlist_id,
             references(:playlists,
               column: :id,
               name: "playlist_items_playlist_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )

      modify :content_id,
             references(:contents,
               column: :id,
               name: "playlist_items_content_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )

      add :added_by_id,
          references(:users,
            column: :id,
            name: "playlist_items_added_by_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :nilify_all
          )
    end

    # Only their owner could add Content to lists
    execute """
    UPDATE playlist_items
    SET added_by_id = playlists.owner_id
    FROM playlists
    WHERE playlists.id = playlist_items.playlist_id
    """

    create table(:playlist_accesses, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :level, :text, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :playlist_id,
          references(:playlists,
            column: :id,
            name: "playlist_accesses_playlist_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :user_id,
          references(:users,
            column: :id,
            name: "playlist_accesses_user_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false
    end

    create unique_index(:playlist_accesses, [:playlist_id, :user_id],
             name: "playlist_accesses_playlist_and_user_index"
           )
  end

  def down do
    drop table(:playlist_accesses)

    drop constraint(:playlist_items, "playlist_items_playlist_id_fkey")
    drop constraint(:playlist_items, "playlist_items_content_id_fkey")

    alter table(:playlist_items) do
      remove :added_by_id

      modify :playlist_id,
             references(:playlists,
               column: :id,
               name: "list_items_list_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )

      modify :content_id,
             references(:contents,
               column: :id,
               name: "list_items_content_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    drop_if_exists unique_index(:playlist_items, [:playlist_id, :content_id],
                     name: "playlist_items_playlist_and_content_index"
                   )

    create unique_index(:playlist_items, [:playlist_id, :content_id],
             name: "list_items_list_and_content_index"
           )

    rename table(:playlist_items), :added_at, to: :created_at
    rename table(:playlist_items), :playlist_id, to: :list_id
    rename table(:playlist_items), to: table(:list_items)

    drop constraint(:playlists, "playlists_owner_id_fkey")

    alter table(:playlists) do
      modify :owner_id,
             references(:users,
               column: :id,
               name: "lists_owner_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    rename table(:playlists), to: table(:lists)
  end
end
