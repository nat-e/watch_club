defmodule WatchClub.Repo.Migrations.AllowMissingTextTrackCodecs do
  @moduledoc "Allows subtitle tracks with missing codec metadata."

  use Ecto.Migration

  def up do
    alter table(:text_tracks) do
      modify :codec, :text, null: true
    end
  end

  def down do
    alter table(:text_tracks) do
      modify :codec, :text, null: false
    end
  end
end
