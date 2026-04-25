defmodule WatchClub.Clubs.Validations.UserNotInClub do
  @moduledoc """
  A Validation that verifies that a User is not already in a Club
  """
  use Ash.Resource.Validation
  require Ash.Query

  @impl true
  def init(opts) do
    cond do
      is_nil(opts[:email]) or not is_atom(opts[:email]) ->
        {:error, ":email must be an atom"}

      is_nil(opts[:club_id]) or not is_atom(opts[:club_id]) ->
        {:error, ":club_id must be an atom"}

      true ->
        {:ok, opts}
    end
  end

  @impl true
  def validate(changeset, _opts, _context) do
    email = Ash.Changeset.get_attribute(changeset, :email)
    club_id = Ash.Changeset.get_attribute(changeset, :club_id)

    if WatchClub.Clubs.Membership
       |> Ash.Query.filter(club_id == ^club_id and user.email == ^email)
       |> Ash.exists?(authorize?: false) do
      {:error, field: :email, message: "user is already a member of the club"}
    else
      :ok
    end
  end
end
