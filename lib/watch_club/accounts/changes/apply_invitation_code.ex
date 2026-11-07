defmodule WatchClub.Accounts.Changes.ApplyInvitationCode do
  @moduledoc """
  Uses an invitation while registering a new user: increments the code use count
  within the registration transaction.

  Everything runs inside the registration transaction, so a failed
  registration rolls the use increment back.
  """
  use Ash.Resource.Change

  use Gettext, backend: WatchClubWeb.Gettext

  alias Ash.Error.Changes.InvalidArgument
  alias WatchClub.Accounts

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    case Ash.Changeset.get_argument(changeset, :invitation_code) do
      nil ->
        changeset

      code ->
        changeset
        |> Ash.Changeset.before_action(&apply_invitation_code(&1, code, context))
    end
  end

  defp apply_invitation_code(changeset, code, context) do
    with {:ok, invitation_code} <- Accounts.view_invitation(code, scope: context),
         {:ok, _accepted} <- use_invitation_code(invitation_code, context) do
      changeset
    else
      {:error, error} ->
        Ash.Changeset.add_error(changeset, to_invitation_code_error(error))
    end
  end

  defp use_invitation_code(invitation, context) do
    invitation
    |> Ash.Changeset.for_update(:use, %{}, scope: context)
    |> Ash.update()
  end

  # Translate domain errors into a single field-level error users can see.
  # The redeemability messages come from the :accept action's validations.
  defp to_invitation_code_error(error) do
    case error do
      %Ash.Error.Query.NotFound{} ->
        invalid(dgettext_noop("errors", "The invitation code is not valid"))

      # Ash.Error.Invalid wraps a list of inner errors – unwrap and recurse
      %Ash.Error.Invalid{errors: [inner | _]} ->
        to_invitation_code_error(inner)

      %{message: message} when is_binary(message) ->
        invalid(message)
    end
  end

  defp invalid(message) do
    InvalidArgument.exception(
      field: :invitation_code,
      message: message
    )
  end
end
