defmodule WatchClub.Clubs.MembershipRole do
  use Ash.Type.Enum, values: [:admin, :member]
end
