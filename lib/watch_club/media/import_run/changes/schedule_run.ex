defmodule WatchClub.Media.ImportRun.Changes.ScheduleRun do
  use Ash.Resource.Change

  alias WatchClub.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, run} <- result do
        AshOban.run_trigger(run, :run, actor: SystemActor.actor())
        {:ok, run}
      end
    end)
  end
end
