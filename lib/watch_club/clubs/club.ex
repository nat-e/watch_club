defmodule WatchClub.Clubs.Club do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "clubs"
    repo(WatchClub.Repo)
  end

  actions do
    defaults [:read, :destroy, create: [:name], update: [:name]]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 2, max_length: 30
    end

    timestamps()
  end
end
