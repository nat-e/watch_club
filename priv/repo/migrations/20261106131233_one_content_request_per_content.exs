defmodule WatchClub.Repo.Migrations.OneContentRequestPerContent do
  @moduledoc """
  Keeps one Content Request per Content, with its Request Subscribers.

  Generated with `mix ash_postgres.generate_migrations`, then edited by hand to merge the
  Content Requests before the unique index on `content_id` is created.
  """

  use Ecto.Migration

  def up do
    create table(:request_subscribers, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :content_request_id,
          references(:content_requests,
            column: :id,
            name: "request_subscribers_content_request_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :user_id,
          references(:users,
            column: :id,
            name: "request_subscribers_user_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false
    end

    create unique_index(:request_subscribers, [:content_request_id, :user_id],
             name: "request_subscribers_unique_request_and_user_index"
           )

    # Every User who requested a Content becomes a Request Subscriber of its earliest
    # Content Request, from when they requested it
    execute """
    INSERT INTO request_subscribers (content_request_id, user_id, inserted_at, updated_at)
    SELECT earliest.id, content_requests.user_id, content_requests.inserted_at,
           content_requests.inserted_at
    FROM content_requests
    JOIN (
      SELECT DISTINCT ON (content_id) id, content_id
      FROM content_requests
      ORDER BY content_id, inserted_at, id
    ) earliest ON earliest.content_id = content_requests.content_id
    """

    # Only the earliest Content Request of each Content stays
    execute """
    DELETE FROM content_requests
    USING content_requests earlier
    WHERE earlier.content_id = content_requests.content_id
      AND (earlier.inserted_at, earlier.id) < (content_requests.inserted_at, content_requests.id)
    """

    drop_if_exists unique_index(:content_requests, [:user_id, :content_id],
                     name: "content_requests_unique_user_content_index"
                   )

    drop constraint(:content_requests, "content_requests_user_id_fkey")

    create unique_index(:content_requests, [:content_id],
             name: "content_requests_unique_content_index"
           )

    rename table(:content_requests), :user_id, to: :requested_by_id

    alter table(:content_requests) do
      modify :requested_by_id,
             references(:users,
               column: :id,
               name: "content_requests_requested_by_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :nilify_all
             ),
             null: true
    end
  end

  # Schema only: the merged Content Requests aren't restorable
  def down do
    drop constraint(:request_subscribers, "request_subscribers_user_id_fkey")

    drop constraint(:request_subscribers, "request_subscribers_content_request_id_fkey")

    drop_if_exists unique_index(:request_subscribers, [:content_request_id, :user_id],
                     name: "request_subscribers_unique_request_and_user_index"
                   )

    drop table(:request_subscribers)

    drop constraint(:content_requests, "content_requests_requested_by_id_fkey")

    # Content Requests used to go with their User
    execute "DELETE FROM content_requests WHERE requested_by_id IS NULL"

    alter table(:content_requests) do
      modify :requested_by_id,
             references(:users,
               column: :id,
               name: "content_requests_user_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             ),
             null: false
    end

    rename table(:content_requests), :requested_by_id, to: :user_id

    drop_if_exists unique_index(:content_requests, [:content_id],
                     name: "content_requests_unique_content_index"
                   )

    create unique_index(:content_requests, [:user_id, :content_id],
             name: "content_requests_unique_user_content_index"
           )
  end
end
