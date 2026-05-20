defmodule WatchClub.Media.Changes.EnqueueMediaImportProcess do
  use Ash.Resource.Change

  alias WatchClub.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, media_import ->
      AshOban.run_trigger(media_import, :process, actor: SystemActor.actor())

      {:ok, media_import}
    end)
  end
end
