defmodule WatchClub.Media.ImportRun.Changes.ScheduleRun do
  use Ash.Resource.Change

  alias WatchClub.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, run ->
      AshOban.run_trigger(run, :run, actor: SystemActor.actor())

      {:ok, run}
    end)
  end
end
