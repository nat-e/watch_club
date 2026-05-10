defmodule WatchClub.Accounts.Preparations.AcceptInvitation do
  use Ash.Resource.Preparation

  use Gettext, backend: WatchClubWeb.Gettext

  require Logger

  @impl true
  def prepare(query, _opts, _context) do
    case Ash.Query.get_argument(query, :invitation_id) do
      nil ->
        query

      invitation_id ->
        Ash.Query.after_action(query, fn
          _changeset, [user] ->
            case accept_invitation(invitation_id, user) do
              :ok -> {:ok, [user]}
              {:error, error} -> {:error, error}
            end

          _changeset, _records ->
            {:error,
             Ash.Error.Query.InvalidQuery.exception(
               field: :invitation_id,
               message: "accepting invitation cannot be done on multiple users"
             )}
        end)
    end
  end

  defp accept_invitation(invitation_id, user) do
    with {:ok, invitation} <-
           WatchClub.Clubs.view_invitation(invitation_id, actor: user),
         {:ok, _accepted?} <-
           WatchClub.Clubs.accept_invitation(invitation, actor: user) do
      :ok
    else
      {:error, error} -> {:error, to_invitation_error(error, invitation_id)}
    end
  end

  # Translate domain errors into a single field-level error users can see.
  defp to_invitation_error(error, invitation_id) do
    case error do
      %Ash.Error.Query.NotFound{} ->
        invalid(dgettext_noop("errors", "The invitation does not exist"))

      %Ash.Error.Changes.InvalidAttribute{message: message} ->
        invalid(message)

      # Ash.Error.Invalid wraps a list of inner errors – unwrap and recurse
      %Ash.Error.Invalid{errors: [inner | _]} ->
        to_invitation_error(inner, invitation_id)

      other ->
        Logger.warning("Unexpected invitation error: #{inspect(other)}")
        invalid(dgettext_noop("errors", "The invitation could not be accepted"))
    end
  end

  defp invalid(message) do
    Ash.Error.Query.InvalidArgument.exception(
      field: :invitation_id,
      message: message
    )
  end
end
