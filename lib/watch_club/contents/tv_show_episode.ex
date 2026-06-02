defmodule WatchClub.Contents.TvShowEpisode do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.TvShow
  alias WatchClub.MediaCatalog.Video

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

  preparations do
    prepare build(load: [:formatted_episode_number])
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

    # Sourced from the Metadata Provider (TMDB season details). Nil when the
    # provider has no date yet. Drives the "aired episodes" denominator for
    # a TV Show's request completeness: an episode counts as aired when
    # air_date is set and not in the future.
    attribute :air_date, :date do
      allow_nil? true
      public? true
    end
  end

  relationships do
    belongs_to :tv_show, TvShow do
      allow_nil? false
    end

    has_many :videos, Video
  end

  calculations do
    calculate :formatted_episode_number,
              :string,
              WatchClub.Contents.TvShowEpisode.Calculations.FormattedEpisodeNumber do
      public? true
    end
  end

  identities do
    identity :unique_position_per_tv_show, [:tv_show_id, :season_number, :episode_number]
  end

  defimpl String.Chars, for: __MODULE__ do
    def to_string(episode) do
      case episode.tv_show do
        %Ash.NotLoaded{} ->
          "[Episode] show:#{episode.tv_show_id} #{episode.formatted_episode_number}"

        %{original_title: title} ->
          "[Episode] #{title} #{episode.formatted_episode_number}"
      end
    end
  end
end
