defmodule WatchClub.Contents.TvShow do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.Content

  postgres do
    table "tv_shows"
    repo(WatchClub.Repo)

    references do
      reference(:content, on_delete: :delete, on_update: :update)
    end
  end

  attributes do
    attribute :id, :uuid_v7 do
      primary_key? true
      allow_nil? false
      public? true
    end

    attribute :original_name, :string do
      allow_nil? false
      public? true
    end

    attribute :tmdb_id, :integer do
      allow_nil? false
      public? true
    end

    attribute :tvdb_id, :integer do
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
  end

  identities do
    identity :unique_content, [:id]
    identity :unique_tmdb_id, [:tmdb_id]
    identity :unique_tvdb_id, [:tvdb_id]
  end
end
