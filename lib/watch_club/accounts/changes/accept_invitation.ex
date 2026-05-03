defmodule WatchClub.Accounts.Changes.AcceptInvitation do
  use Ash.Resource.Change

  alias Ash.Error.Changes.InvalidArgument

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :invitation_id) do
      nil ->
        changeset

      invitation_id ->
        Ash.Changeset.after_action(changeset, fn _changeset, user ->
          accept_invitation(invitation_id, user)
        end)
    end
  end

  defp accept_invitation(invitation_id, user) do
    with {:ok, invitation} <-
           WatchClub.Clubs.view_invitation(invitation_id, actor: user),
         {:ok, _accepted} <-
           WatchClub.Clubs.accept_invitation(invitation, actor: user) do
      {:ok, user}
    else
      {:error, error} -> {:error, to_invitation_error(error, invitation_id)}
    end
  end

  # Translate domain errors into a single field-level error users can see.
  defp to_invitation_error(error, invitation_id) do
    case error do
      %Ash.Error.Query.NotFound{} ->
        invalid("invitation not found")

      %AshStateMachine.Errors.NoMatchingTransition{old_state: :accepted} ->
        invalid("invitation has already been used")

      %AshStateMachine.Errors.NoMatchingTransition{old_state: :cancelled} ->
        invalid("invitation has been cancelled")

      # Ash.Error.Invalid wraps a list of inner errors – unwrap and recurse
      %Ash.Error.Invalid{errors: [inner | _]} ->
        to_invitation_error(inner, invitation_id)

      %Ash.Error.Changes.InvalidAttribute{field: :expires_at} ->
        invalid("invitation has expired")

      other ->
        Logger.warning("Unexpected invitation error: #{inspect(other)}")
        invalid("invitation could not be accepted")
    end
  end

  defp invalid(message) do
    InvalidArgument.exception(
      field: :invitation_id,
      message: message
    )
  end
end
