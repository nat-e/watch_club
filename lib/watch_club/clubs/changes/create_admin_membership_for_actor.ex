defmodule WatchClub.Clubs.Changes.CreateAdminMembershipForActor do
  @moduledoc """
  Creates a club admin membership for the actor creating the club.
  """
  use Ash.Resource.Change

  alias WatchClub.Accounts.User

  @impl true
  def change(changeset, _opts, %{actor: %User{} = actor}) do
    Ash.Changeset.manage_relationship(
      changeset,
      :memberships,
      [%{user_id: actor.id, role: :admin}],
      type: :create,
      authorize?: false
    )
  end

  # The changeset is still executed when the actor is nil, even if policy forbids it.
  def change(changeset, _opts, _context), do: changeset
end
