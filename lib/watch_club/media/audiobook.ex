defmodule WatchClub.Media.Audiobook do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Contents.Book
  alias WatchClub.Media.Media

  postgres do
    table "audiobooks"
    repo(WatchClub.Repo)

    references do
      reference(:media, on_delete: :delete, on_update: :update)
      reference(:book, on_delete: :restrict, on_update: :update)
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:book_id]
    end
  end

  policies do
    policy actor_absent() do
      description "Audiobook actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action([:read, :create]) do
      description "Only the Instance Administrator can manage Audiobooks directly"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  attributes do
    attribute :id, :uuid_v7 do
      primary_key? true
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :media, Media do
      primary_key? true
      allow_nil? false
      define_attribute? false
      source_attribute :id
    end

    belongs_to :book, Book do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_media, [:id]
  end
end
