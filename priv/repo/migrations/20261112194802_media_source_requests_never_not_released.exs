defmodule WatchClub.Repo.Migrations.MediaSourceRequestsNeverNotReleased do
  use Ecto.Migration

  # Only the Content Request Status is Not Released, from its Content's release date
  def up do
    execute "UPDATE media_source_requests SET status = 'searching' WHERE status = 'not_released'"
  end

  def down, do: :ok
end
