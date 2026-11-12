defmodule WatchClub.Accounts.Changes.DeleteOldPhoto do
  @moduledoc """
  Once the action commits, deletes the file of the photo the User had before it, if any.
  """
  use Ash.Resource.Change

  alias WatchClub.Accounts.UserPhoto

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn changeset, result ->
      with {:ok, _user} <- result do
        UserPhoto.delete(changeset.data.photo_revision)
      end

      result
    end)
  end
end
