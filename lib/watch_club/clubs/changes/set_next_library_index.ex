defmodule WatchClub.Clubs.Changes.SetNextLibraryIndex do
  @moduledoc """
  Sets the new library index after the last existing library in the club.
  """
  use Ash.Resource.Change

  alias WatchClub.Clubs.Library

  require Ash.Query

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      club_id = Ash.Changeset.get_attribute(changeset, :club_id)

      max_index =
        Library
        |> Ash.Query.for_read(:read, %{}, scope: context)
        |> Ash.Query.filter(club_id == ^club_id)
        |> Ash.max!(:index)

      Ash.Changeset.force_change_attribute(changeset, :index, (max_index || -1) + 1)
    end)
  end
end
