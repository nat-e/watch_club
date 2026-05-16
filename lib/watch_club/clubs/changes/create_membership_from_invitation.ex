defmodule WatchClub.Clubs.Changes.CreateMembershipFromInvitation do
  @moduledoc """
  Creates the invited user's membership when an invitation is accepted.
  """
  use Ash.Resource.Change

  alias WatchClub.Accounts.User

  @impl true
  def change(changeset, _opts, %{actor: %User{} = actor}) do
    Ash.Changeset.manage_relationship(
      changeset,
      :created_membership,
      [
        %{
          club_id: Ash.Changeset.get_attribute(changeset, :club_id),
          user_id: actor.id,
          role: Ash.Changeset.get_attribute(changeset, :role)
        }
      ],
      type: :create,
      authorize?: false
    )
  end
end
