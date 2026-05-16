defmodule WatchClub.Contents.Checks.ActorCanAccessSelectedLibraries do
  @moduledoc """
  Authorizes content actions that select club libraries.

  Content is global, but adding it to libraries is scoped by club access.
  When no libraries are selected, the action only affects global content metadata.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.Library

  @impl true
  def describe(_opts), do: "actor can access all selected libraries"

  @impl true
  def match?(%User{} = actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    changeset
    |> Ash.Changeset.get_argument(:library_ids)
    |> selected_libraries_accessible?(actor)
  end

  def match?(_, _, _), do: false

  defp selected_libraries_accessible?(nil, _actor), do: true
  defp selected_libraries_accessible?([], _actor), do: true

  defp selected_libraries_accessible?(library_ids, %User{} = actor) do
    library_ids = library_ids |> Enum.reject(&is_nil/1) |> Enum.uniq()

    Library
    |> Ash.Query.for_read(:read, %{}, authorize?: false)
    |> Ash.Query.filter(id in ^library_ids)
    |> Ash.Query.filter(exists(club.memberships, user_id == ^actor.id))
    |> Ash.count!()
    |> Kernel.==(length(library_ids))
  end
end
