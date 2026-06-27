defmodule WatchClub.Accounts.ClubInvitation do
  @moduledoc """
  Join resource recording that an invitation code grants membership to a club.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Accounts,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Accounts.InvitationCode
  alias WatchClub.Clubs.Club

  postgres do
    table "club_invitations"
    repo WatchClub.Repo

    references do
      # Deleting a club drops it from every invitation code that grants it; the
      # invitations themselves survive.
      reference :club, on_delete: :delete
      reference :invitation_code, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, create: [:*]]
  end

  attributes do
    uuid_v7_primary_key :id
  end

  relationships do
    belongs_to :invitation_code, InvitationCode, allow_nil?: false, public?: true
    belongs_to :club, Club, allow_nil?: false, public?: true
  end

  identities do
    identity :invitation_and_club, [:invitation_code_id, :club_id]
  end
end
