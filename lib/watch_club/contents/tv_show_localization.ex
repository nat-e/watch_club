defmodule WatchClub.Contents.TvShowLocalization do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.{Calculations.LocalizationRank, TvShow}
  alias WatchClub.Contents.Preparations.SortLocalizationsByRank

  postgres do
    table "tv_show_localizations"
    repo WatchClub.Repo

    references do
      reference :tv_show, on_delete: :delete
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

    attribute :cast, {:array, WatchClub.Contents.CastMember} do
      allow_nil? false
      default []
      public? true
    end

    attribute :trailer_url, :string, public?: true

    timestamps()
  end

  relationships do
    belongs_to :tv_show, TvShow do
      allow_nil? false
    end
  end

  calculations do
    calculate :rank, :integer, LocalizationRank do
      argument :preferred_iso_639_1, :string do
        allow_nil? false
      end

      argument :preferred_iso_3166_1, :string do
        allow_nil? false
      end

      allow_nil? false
    end
  end

  identities do
    identity :unique_locale_per_tv_show, [:tv_show_id, :iso_639_1, :iso_3166_1]
  end
end
