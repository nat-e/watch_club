defmodule WatchClub.Clubs.Checks.ActorIsClubMember do
  @moduledoc """
  A simple check that validates that the actor has a ClubMembership for a given club.
  If a specific role is required, it can be passed in the :role argument
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.{Membership, MembershipRole}

  @impl true
  def init(options) do
    case Keyword.fetch(options, :role) do
      {:ok, role} ->
        if role in MembershipRole.values() do
          {:ok, options}
        else
          {:error, "Role must be one of: #{Enum.join(MembershipRole.values(), ", ")}"}
        end

      _ ->
        {:ok, options}
    end
  end

  @impl true
  def describe(options) do
    case options[:role] do
      nil -> "actor is a member of the club"
      role -> "actor is a #{role} in the club"
    end
  end

  @impl true
  def match?(%User{} = actor, context, options) do
    case extract_club_id(context) do
      nil -> false
      club_id -> has_club_membership(club_id, actor.id, options[:role])
    end
  end

  def match?(_, _, _), do: false

  defp extract_club_id(%{changeset: %Ash.Changeset{} = changeset}) do
    Ash.Changeset.get_argument_or_attribute(changeset, :club_id)
  end

  defp extract_club_id(%{query: %Ash.Query{} = query}),
    do: Ash.Query.get_argument(query, :club_id)

  defp extract_club_id(%{action_input: %Ash.ActionInput{} = input}),
    do: Ash.ActionInput.get_argument(input, :club_id)

  defp extract_club_id(_), do: nil

  defp has_club_membership(club_id, user_id, role) do
    Membership
    |> Ash.Query.for_read(:read, %{}, authorize?: false)
    |> Ash.Query.filter(club_id == ^club_id and user_id == ^user_id)
    |> filter_by_role(role)
    |> Ash.exists?()
  end

  defp filter_by_role(filter, nil), do: filter
  defp filter_by_role(filter, role), do: Ash.Query.filter(filter, role == ^role)
end
