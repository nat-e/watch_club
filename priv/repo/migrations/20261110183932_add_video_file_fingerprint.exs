defmodule WatchClub.Repo.Migrations.AddVideoFileFingerprint do
  @moduledoc """
  Adds each Video's File Fingerprint. Existing Videos get a random one, so the next Media Import
  or webhook that processes their file finds it changed.
  """

  use Ecto.Migration

  def up do
    alter table(:videos) do
      # A volatile default gives each existing row its own value
      add :file_fingerprint, :text, null: false, default: fragment("md5(random()::text)")
    end

    execute("ALTER TABLE videos ALTER COLUMN file_fingerprint DROP DEFAULT")
  end

  def down do
    alter table(:videos) do
      remove :file_fingerprint
    end
  end
end
