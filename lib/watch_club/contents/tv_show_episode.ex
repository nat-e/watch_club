defmodule WatchClub.Contents.TvShowEpisode do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.TvShow
  alias WatchClub.History.{WatchProgress, WatchStatus}
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

    read :for_show do
      description "Retrieves all episodes of a TV show for a given TMDB ID"
      argument :tmdb_id, :integer, allow_nil?: false

      filter expr(
               tv_show.content.external_id_source == :tmdb and
                 tv_show.content.external_id == ^arg(:tmdb_id)
             )
    end
  end

  preparations do
    prepare build(
              load: [:formatted_episode_number],
              sort: [tv_show_id: :asc, season_number: :asc, episode_number: :asc]
            )
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

    # The path to the still image (16/9)
    attribute :still_path, :string do
      allow_nil? true
      public? true
    end
  end

  relationships do
    belongs_to :tv_show, TvShow do
      allow_nil? false
    end

    has_many :videos, Video
    has_many :watch_progresses, WatchProgress

    has_one :actor_progress, WatchProgress do
      from_many? true
      filter expr(user_id == ^actor(:id))
    end
  end

  calculations do
    calculate :formatted_episode_number,
              :string,
              WatchClub.Contents.TvShowEpisode.Calculations.FormattedEpisodeNumber do
      public? true
    end

    calculate :has_media?, :boolean, expr(videos_count > 0)

    calculate :actor_progress_status,
              WatchStatus,
              expr(
                cond do
                  is_nil(actor_progress) -> :not_started
                  actor_progress.completed -> :completed
                  true -> :in_progress
                end
              )
  end

  aggregates do
    count :videos_count, :videos
    # The date at which the current user has most recently watched this episode, or nil
    first :actor_last_watched_at, :actor_progress, :updated_at
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
