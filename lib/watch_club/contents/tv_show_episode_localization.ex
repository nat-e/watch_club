defmodule WatchClub.Contents.TvShowEpisodeLocalization do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.Calculations.LocalizationRank
  alias WatchClub.Contents.Preparations.SortLocalizationsByRank
  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.Shared.AnyFieldChanged

  postgres do
    table "tv_show_episode_localizations"
    repo WatchClub.Repo

    identity_index_names unique_locale_per_tv_show_episode:
                           "tv_show_episode_localizations_unique_locale_index"

    references do
      reference :tv_show_episode, on_delete: :delete
    end
  end

  # The metadata a refresh overwrites
  @refreshed_fields [:title, :overview]

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:tv_show_episode_id, :iso_639_1, :iso_3166_1 | @refreshed_fields]
      upsert? true
      upsert_identity :unique_locale_per_tv_show_episode
      upsert_fields @refreshed_fields
      upsert_condition AnyFieldChanged.expr(@refreshed_fields)
    end
  end

  preparations do
    prepare SortLocalizationsByRank
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :iso_639_1, :string, allow_nil?: false, public?: true
    attribute :iso_3166_1, :string, allow_nil?: false, public?: true
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :overview, :string, public?: true

    timestamps()
  end

  relationships do
    belongs_to :tv_show_episode, TvShowEpisode, allow_nil?: false
  end

  calculations do
    calculate :rank, :integer, LocalizationRank do
      argument :preferred_iso_639_1, :string, allow_nil?: false
      argument :preferred_iso_3166_1, :string, allow_nil?: false
      allow_nil? false
    end
  end

  identities do
    identity :unique_locale_per_tv_show_episode, [
      :tv_show_episode_id,
      :iso_639_1,
      :iso_3166_1
    ]
  end
end
