defmodule WatchClub.Clubs.Checks.ActorCanCreateLibraryItem do
  @moduledoc """
  A simple check that validates whether the user is allowed to create a club library item
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  @impl true
  def init(options) do
    {:ok, options}
  end

  @impl true
  def describe(_options) do
    "actor is a member of the club"
  end

  @impl true
  def match?(_actor, %{changeset: %Ash.Changeset{} = changeset}, _options) do
    library_id = Ash.Changeset.get_argument(:library_id, changeset)

    Library
    |> Ash.Query.filter(id == ^library_id)
    |> Ash.Query.filter(exists(club.memerships.user_id == ^actor(:id)))
    |> Ash.exists?(authorize?: false)
  end
end
