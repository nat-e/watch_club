defmodule WatchClub.Accounts.Changes.DeleteOldProfilePicture do
  @moduledoc """
  Once the action commits, deletes the file of the profile picture the User had before it, if
  any.
  """
  use Ash.Resource.Change

  alias WatchClub.Accounts.ProfilePicture

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn changeset, result ->
      with {:ok, _user} <- result do
        ProfilePicture.delete(changeset.data.profile_picture_revision)
      end

      result
    end)
  end
end
