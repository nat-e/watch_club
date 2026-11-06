defmodule WatchClub.History.Watcher do
  @moduledoc """
  A User who watched a Content or is watching it, and when they last did.
  """
  alias WatchClub.Accounts.User

  @type t :: %__MODULE__{
          user: User.t(),
          status: :in_progress | :completed,
          last_watched_at: DateTime.t()
        }

  defstruct [:user, :status, :last_watched_at]
end
