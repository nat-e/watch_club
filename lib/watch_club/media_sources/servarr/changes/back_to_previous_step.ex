defmodule WatchClub.MediaSources.Servarr.Changes.BackToPreviousStep do
  @moduledoc """
  Dynamically picks the previous step for the wizard's
  `:back_to_previous_step` action. Used in place of the built-in
  `transition_state/1` because the target depends on the current state.

  Pairs with the two `transition :back_to_previous_step, ...` declarations
  on the resource — the state machine still validates that the resulting
  `(from, to)` pair is allowed.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    target =
      case Ash.Changeset.get_attribute(changeset, :step) do
        :request_profile -> :connection
        :webhook -> :request_profile
      end

    AshStateMachine.transition_state(changeset, target)
  end
end
