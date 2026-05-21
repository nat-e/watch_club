defmodule WatchClub.Contents.TvShowEpisode do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.TvShow
  alias WatchClub.Media.Video

  postgres do
    table "tv_show_episodes"
    repo WatchClub.Repo

    references do
      reference :tv_show, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :season_number, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :episode_number, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end
  end

  relationships do
    belongs_to :tv_show, TvShow do
      allow_nil? false
    end

    has_many :videos, Video
  end

  identities do
    identity :unique_position_per_tv_show, [:tv_show_id, :season_number, :episode_number]
  end
end
