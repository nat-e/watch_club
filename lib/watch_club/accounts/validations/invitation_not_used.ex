defmodule WatchClub.Accounts.Validations.InvitationNotUsed do
  @moduledoc """
  Forbids the action when the invitation has reached its max uses.

  Supports atomic execution: the failure condition compiles into the UPDATE
  statement itself, where it is evaluated against the row's latest committed
  version under its row lock — concurrent redemptions cannot exceed max uses.
  """
  use Ash.Resource.Validation

  import Ash.Expr

  alias Ash.Error.Changes.InvalidAttribute

  @impl Ash.Resource.Validation
  def validate(%Ash.Changeset{data: invitation}, _opts, _context) do
    if invitation.max_uses && invitation.uses >= invitation.max_uses do
      {:error, field: :uses}
    else
      :ok
    end
  end

  @impl Ash.Resource.Validation
  def atomic(_changeset, _opts, context) do
    # Plain refs read the row's current (pre-increment) values
    {:atomic, [:uses, :max_uses], expr(not is_nil(max_uses) and uses >= max_uses),
     expr(
       error(^InvalidAttribute, %{
         field: :uses,
         message: ^(context.message || "has already been used")
       })
     )}
  end
end
