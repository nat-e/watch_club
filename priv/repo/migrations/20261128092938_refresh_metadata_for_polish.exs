defmodule WatchClub.Repo.Migrations.RefreshMetadataForPolish do
  use Ecto.Migration

  # Fetches the Polish localizations of the stored Content
  def up do
    execute """
    INSERT INTO oban_jobs (worker, queue, max_attempts)
    SELECT 'WatchClub.Contents.Workers.RefreshAllMetadata', 'metadata_refreshes', 3
    WHERE EXISTS (SELECT 1 FROM contents)
    """
  end

  def down do
    execute """
    DELETE FROM oban_jobs
    WHERE worker = 'WatchClub.Contents.Workers.RefreshAllMetadata' AND state = 'available'
    """
  end
end
