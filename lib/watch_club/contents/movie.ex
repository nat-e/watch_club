defmodule WatchClub.Contents.Movie do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.{Content, ContentView, MovieLocalization}

  postgres do
    table "movies"
    repo(WatchClub.Repo)

    references do
      reference(:content, on_delete: :delete, on_update: :update)
    end
  end

  actions do
    create :create do
      description "Fetches a Movie from TMDB and creates it in DB. Content and MovieLocalization will also be created"
      primary? true
      accept [:tmdb_id]
      argument :club_ids, {:array, :uuid_v7}, allow_nil?: true

      change WatchClub.Contents.Changes.CreateOrUpdateMovie, only_when_valid?: true
      change WatchClub.Contents.Changes.SetInClubLibraries, where: [present(:club_ids)]
    end

    action :details, :struct do
      constraints instance_of: ContentView
      argument :tmdb_id, :integer, allow_nil?: false

      run WatchClub.Contents.Actions.GetMovieDetails
    end
  end

  attributes do
    attribute :id, :uuid_v7 do
      primary_key? true
      allow_nil? false
      public? true
    end

    attribute :tmdb_id, :integer do
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

    has_many :localizations, MovieLocalization
  end

  identities do
    identity :unique_content, [:id]
    identity :unique_tmdb_id, [:tmdb_id]
  end
end
