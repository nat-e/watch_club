defmodule WatchClub.Contents.MovieLocalization do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.{Calculations.LocalizationRank, Movie}
  alias WatchClub.Contents.Preparations.SortLocalizationsByRank

  postgres do
    table "movie_localizations"
    repo WatchClub.Repo

    references do
      reference :movie, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  preparations do
    prepare SortLocalizationsByRank
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :iso_639_1, :string do
      allow_nil? false
      public? true
    end

    attribute :iso_3166_1, :string do
      allow_nil? false
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :overview, :string do
      allow_nil? true
      public? true
    end

    attribute :poster_path, :string do
      allow_nil? true
      public? true
    end

    attribute :runtime, :integer do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :movie, Movie do
      allow_nil? false
    end
  end

  calculations do
    calculate :rank, :integer, LocalizationRank do
      argument :preferred_iso_639_1, :string, allow_nil?: false
      argument :preferred_iso_3166_1, :string, allow_nil?: false
      allow_nil? false
    end
  end

  identities do
    identity :unique_locale_per_movie, [:movie_id, :iso_639_1, :iso_3166_1]
  end
end
