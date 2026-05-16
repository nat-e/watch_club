defmodule WatchClub.Clubs.Changes.RemoveUnacceptedLibraryItems do
  @moduledoc """
  Removes library items whose content type is not accepted by the library.
  """
  use Ash.Resource.Change

  alias WatchClub.Clubs.LibraryItem

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, library ->
      accepted_content_types = library.accepted_content_types

      LibraryItem
      |> Ash.Query.filter(library_id == ^library.id)
      |> Ash.Query.filter(content.type not in ^accepted_content_types)
      |> Ash.read!(scope: context)
      |> Enum.each(&Ash.destroy!(&1, scope: context))

      {:ok, library}
    end)
  end
end
