defmodule WatchClub.Media.MediaImport.Changes.Schedule do
  use Ash.Resource.Change

  alias WatchClub.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, media_import} <- result do
        AshOban.run_trigger(media_import, :run, actor: SystemActor.actor())
        {:ok, media_import}
      end
    end)
  end
end
