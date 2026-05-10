defmodule WatchClub.Clubs.Checks.ActorIsClubMemberFilter do
  @moduledoc """
  A filter check for resources that belong to a Club that validates that filters the rows
  where the actor is a Club Member with a specific role.
  """
  alias WatchClub.Clubs.MembershipRole
  use Ash.Policy.FilterCheck

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
  def filter(_actor, _context, options) do
    club_path = Keyword.get(options, :club_path, [:club])
    membership_path = List.wrap(club_path) ++ [:memberships]

    case options[:role] do
      nil -> expr(exists(^membership_path, user_id == ^actor(:id)))
      role -> expr(exists(^membership_path, user_id == ^actor(:id) and role == ^role))
    end
  end
end
