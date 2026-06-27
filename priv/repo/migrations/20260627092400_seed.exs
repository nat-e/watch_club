defmodule WatchClub.Repo.Migrations.Seed do
  @moduledoc """
  Populates data that every installation needs to exist from the start.

  For now this is the single `instance_settings` row. The insert is idempotent
  (the `singleton` unique index makes a second row impossible) so it is safe to
  run on a database that has already been seeded.
  """

  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO instance_settings (id, name, singleton, inserted_at, updated_at)
    VALUES (
      uuid_generate_v7(),
      'Watch Club',
      true,
      now() AT TIME ZONE 'utc',
      now() AT TIME ZONE 'utc'
    )
    ON CONFLICT (singleton) DO NOTHING
    """)
  end

  def down do
    execute("DELETE FROM instance_settings WHERE singleton = true")
  end
end
