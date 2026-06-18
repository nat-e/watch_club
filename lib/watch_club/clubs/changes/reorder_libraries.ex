defmodule WatchClub.Clubs.Changes.ReorderLibraries do
  @moduledoc """
  Reorders all libraries that belong to a club.

  The client sends the full ordered list of library IDs. We verify that it is an
  exact permutation of the club's current libraries before updating indexes.
  If `library_ids` is `nil`, the current order is preserved.
  """
  use Ash.Resource.Change

  alias Ash.Error.Action.InvalidArgument

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :library_ids) do
      nil ->
        changeset

      library_ids ->
        %{libraries: libraries} = Ash.load!(changeset.data, :libraries, authorize?: false)

        if Enum.sort(Enum.map(libraries, & &1.id)) == Enum.sort(library_ids) do
          input = Enum.with_index(library_ids, &%{id: &1, index: &2})

          Ash.Changeset.manage_relationship(changeset, :libraries, input,
            type: :direct_control,
            on_match: {:update, :set_index},
            authorize?: false
          )
        else
          Ash.Changeset.add_error(
            changeset,
            InvalidArgument.exception(
              field: :library_ids,
              message: "must include each club library exactly once",
              value: library_ids
            )
          )
        end
    end
  end
end
