defmodule WatchClub.Clubs.Actions.ReorderLibraries do
  @moduledoc """
  Reorders all libraries that belong to a club.

  The client sends the full ordered list of library IDs. We verify that it is an
  exact permutation of the club's current libraries before updating indexes.
  If `library_ids` is `nil`, the current order is preserved.
  """
  use Ash.Resource.Actions.Implementation

  alias Ash.Error.Action.InvalidArgument
  alias WatchClub.Clubs

  @impl true
  def run(input, _opts, context) do
    club_id = Ash.ActionInput.get_argument(input, :club_id)
    library_ids = Ash.ActionInput.get_argument(input, :library_ids)

    with {:ok, libraries} <- Clubs.list_club_libraries(club_id, scope: context),
         :ok <- validate_library_order(libraries, library_ids),
         {:ok, libraries} <- update_library_indexes(libraries, library_ids, context) do
      {:ok, libraries}
    else
      {:error, error} ->
        {:error, error}
    end
  end

  defp validate_library_order(_libraries, nil), do: :ok

  defp validate_library_order(libraries, ordered_ids) do
    current_ids = Enum.map(libraries, & &1.id)

    if Enum.sort(current_ids) == Enum.sort(ordered_ids) do
      :ok
    else
      {:error,
       InvalidArgument.exception(
         field: :library_ids,
         message: "must include each club library exactly once",
         value: ordered_ids
       )}
    end
  end

  defp update_library_indexes(libraries, nil, scope) do
    update_library_indexes(libraries, Enum.map(libraries, & &1.id), scope)
  end

  defp update_library_indexes(libraries, ordered_ids, scope) do
    libraries_by_id = Map.new(libraries, fn library -> {library.id, library} end)

    ordered_ids
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {library_id, index}, {:ok, libraries} ->
      library = Map.fetch!(libraries_by_id, library_id)

      case update_library_index(library, index, scope) do
        {:ok, library} -> {:cont, {:ok, [library | libraries]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, libraries} -> {:ok, Enum.reverse(libraries)}
      {:error, error} -> {:error, error}
    end
  end

  defp update_library_index(library, index, scope) do
    if index == library.index do
      {:ok, library}
    else
      library
      |> Ash.Changeset.for_update(:set_index, %{index: index}, scope: scope)
      |> Ash.update()
    end
  end
end
