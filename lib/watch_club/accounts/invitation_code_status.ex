defmodule WatchClub.Accounts.InvitationCodeStatus do
  @moduledoc """
  Status on an invitation
  """
  use Ash.Type.Enum, values: [:active, :expired, :disabled, :used]
end
