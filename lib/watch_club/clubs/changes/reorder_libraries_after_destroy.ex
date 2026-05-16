defmodule WatchClub.Clubs.Changes.ReorderLibrariesAfterDestroy do
  @moduledoc """
  Recomputes sibling library indexes after a library is destroyed.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      case WatchClub.Clubs.reorder_libraries(record.club_id, %{}, scope: context) do
        {:ok, _} -> {:ok, record}
        {:error, _} -> {:ok, record}
      end
    end)
  end
end
