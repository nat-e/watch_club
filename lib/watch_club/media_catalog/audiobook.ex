defmodule WatchClub.MediaCatalog.Audiobook do
  @moduledoc """
  Concrete Media for a playable audio book file. Attached to exactly one `Book`.

  `Audiobook.id` is the same value as its parent `Media.id` (shared primary key,
  no separate `media_id` column).

  Direct creation is reserved for Instance Administrator access; the production
  path goes through `WatchClub.MediaCatalog.create_audiobook/2`, which uses relationship
  management to create the Audiobook alongside its parent Media.
  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.MediaCatalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Contents.Book
  alias WatchClub.MediaCatalog.Media

  postgres do
    table "audiobooks"
    repo WatchClub.Repo

    references do
      reference :media, on_delete: :delete
      reference :book, on_delete: :restrict
    end
  end

  actions do
    defaults [:read, :destroy, update: [:book_id]]

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

    policy action_type(:read) do
      description "Any authenticated actor can read Audiobooks"
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      description "Only the system actor can write Audiobooks"
      authorize_if actor_attribute_equals(:system?, true)
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
end
