defmodule WatchClub.History.Watcher do
  @moduledoc """
  A User who watched a Content or is watching it, and when they last did.
  """
  use Ash.TypedStruct

  alias WatchClub.Accounts.User
  alias WatchClub.History.WatchStatus

  typed_struct do
    field :user, :struct, allow_nil?: false, constraints: [instance_of: User]

    field :status, WatchStatus,
      allow_nil?: false,
      description: "In progress, or completed once they finished it"

    field :last_watched_at, :utc_datetime_usec, allow_nil?: false
  end
end
