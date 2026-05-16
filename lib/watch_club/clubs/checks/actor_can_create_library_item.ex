defmodule WatchClub.Clubs.Checks.ActorCanCreateLibraryItem do
  @moduledoc """
  A simple check that validates whether the user is a member of the club that owns the library.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.Library

  @impl true
  def init(options) do
    {:ok, options}
  end

  @impl true
  def describe(_options) do
    "actor is a member of the club"
  end

  @impl true
  def match?(%User{} = actor, %{changeset: %Ash.Changeset{} = changeset}, _options) do
    changeset
    |> Ash.Changeset.get_argument_or_attribute(:library_id)
    |> actor_is_library_club_member?(actor)
  end

  def match?(_, _, _), do: false

  defp actor_is_library_club_member?(nil, _actor), do: false

  defp actor_is_library_club_member?(library_id, %User{} = actor) do
    Library
    |> Ash.Query.filter(id == ^library_id)
    |> Ash.Query.filter(exists(club.memberships, user_id == ^actor.id))
    |> Ash.exists?(authorize?: false)
  end
end
