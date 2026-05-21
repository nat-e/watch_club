defmodule WatchClub.Contents.Book do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.Content
  alias WatchClub.Media.{Audiobook, Ebook}

  postgres do
    table "books"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy, create: [], update: []]
  end

  attributes do
    attribute :id, :uuid_v7 do
      primary_key? true
      allow_nil? false
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :hardcover_id, :integer do
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :content, Content do
      primary_key? true
      allow_nil? false
      define_attribute? false
      source_attribute :id
    end

    has_many :ebooks, Ebook
    has_many :audiobooks, Audiobook
  end

  identities do
    identity :unique_content, [:id]
    identity :unique_hardcover_id, [:hardcover_id]
  end
end
