defmodule WatchClub.Contents.TvShow do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Contents.{Content, ContentView, TvShowEpisode, TvShowLocalization}
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse

  postgres do
    table "tv_shows"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy, update: []]

    create :create do
      primary? true
      accept [:original_name, :tmdb_id, :tvdb_id]

      argument :localizations, {:array, :map}, allow_nil?: false, default: []
      argument :episodes, {:array, :map}, allow_nil?: false, default: []

      change manage_relationship(:localizations, type: :direct_control)
      change manage_relationship(:episodes, type: :direct_control)
    end

    action :details, :struct do
      constraints instance_of: ContentView
      argument :tmdb_id, :integer, allow_nil?: false

      run WatchClub.Contents.Actions.GetTvShowDetails
    end

    action :season_details, :struct do
      constraints instance_of: TvDetailsResponse.SeasonDetails
      argument :tmdb_id, :integer, allow_nil?: false
      argument :season_number, :integer, allow_nil?: false

      run WatchClub.Contents.Actions.GetTvShowSeasonDetails
    end
  end

  policies do
    policy actor_absent() do
      description "TV Show actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action([:read, :details, :season_details]) do
      description "TV Show metadata and details are visible to authenticated users"
      authorize_if always()
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

    has_many :localizations, TvShowLocalization
    has_many :episodes, TvShowEpisode

    has_one :best_localization, TvShowLocalization do
      from_many? true
    end
  end

  identities do
    identity :unique_content, [:id]
    identity :unique_tmdb_id, [:tmdb_id]
    identity :unique_tvdb_id, [:tvdb_id]
  end
end
