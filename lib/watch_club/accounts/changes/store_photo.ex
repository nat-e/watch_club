defmodule WatchClub.Accounts.Changes.StorePhoto do
  @moduledoc """
  Stores the image of the `photo` argument as the User's photo. It's re-encoded before the
  transaction, which it doesn't hold open, and deleted again when the action fails.
  """
  use Ash.Resource.Change

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.UserPhoto

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_transaction(fn changeset ->
      # Every Ash.Type.File source the app uses, a path or a Plug.Upload, has a path
      {:ok, path} = changeset |> Ash.Changeset.get_argument(:photo) |> Ash.Type.File.path()

      case UserPhoto.store(path) do
        {:ok, revision} ->
          Ash.Changeset.force_change_attribute(changeset, :photo_revision, revision)

        {:error, :unreadable} ->
          Ash.Changeset.add_error(changeset,
            field: :photo,
            message: dgettext_noop("errors", "Choose a JPEG, PNG or WebP photo")
          )
      end
    end)
    |> Ash.Changeset.after_transaction(fn changeset, result ->
      with {:error, _error} <- result,
           {:ok, new_revision} <- Ash.Changeset.fetch_change(changeset, :photo_revision) do
        UserPhoto.delete(new_revision)
      end

      result
    end)
  end
end
