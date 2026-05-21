defmodule WatchClub.Media.ImportRun.Changes.EnqueueProcess do
  use Ash.Resource.Change

  alias WatchClub.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, import_run ->
      AshOban.run_trigger(import_run, :process, actor: SystemActor.actor())

      {:ok, import_run}
    end)
  end
end
