defmodule WatchClub.Accounts.Changes.StoreProfilePicture do
  @moduledoc """
  Stores the image of the `profile_picture` argument as the User's profile picture. It's
  re-encoded before the transaction, which it doesn't hold open, and deleted again when the
  action fails.
  """
  use Ash.Resource.Change

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.ProfilePicture

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_transaction(fn changeset ->
      # Every Ash.Type.File source the app uses, a path or a Plug.Upload, has a path
      {:ok, path} =
        changeset |> Ash.Changeset.get_argument(:profile_picture) |> Ash.Type.File.path()

      case ProfilePicture.store(path) do
        {:ok, revision} ->
          Ash.Changeset.force_change_attribute(changeset, :profile_picture_revision, revision)

        {:error, :unreadable} ->
          Ash.Changeset.add_error(changeset,
            field: :profile_picture,
            message:
              dgettext_noop(
                "errors",
                "We can't open this file. Choose a JPEG, PNG or WebP image."
              )
          )
      end
    end)
    |> Ash.Changeset.after_transaction(fn changeset, result ->
      with {:error, _error} <- result,
           {:ok, new_revision} <-
             Ash.Changeset.fetch_change(changeset, :profile_picture_revision) do
        ProfilePicture.delete(new_revision)
      end

      result
    end)
  end
end
