defmodule WatchClub.Contents.TvShow do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.{Content, TvShowEpisode, TvShowLocalization}
  alias WatchClub.History.WatchStatus
  alias WatchClub.Shared.AnyFieldChanged

  postgres do
    table "tv_shows"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :delete
    end
  end

  # The metadata a refresh overwrites
  @refreshed_fields [:original_name, :backdrop_path, :tmdb_id, :tvdb_id]

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:id | @refreshed_fields]
      upsert? true
      upsert_fields @refreshed_fields
      upsert_condition AnyFieldChanged.expr(@refreshed_fields)
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

    attribute :backdrop_path, :string do
      public? true
    end

    attribute :tmdb_id, :integer do
      allow_nil? false
      public? true
    end

    # Optional: Sometimes TMDB does not have the TVDB ID of the Show, even if it exists
    attribute :tvdb_id, :integer do
      allow_nil? true
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

    # The aired TV Show Episode Play starts for the actor. See `actor_next_episode_rank`.
    has_one :actor_next_episode, TvShowEpisode do
      filter expr(actor_next?)
    end

    # The best localization based on the current user locale
    has_one :best_localization, TvShowLocalization do
      from_many? true
    end
  end

  calculations do
    # The progress status of the show for the current user
    # A show is completed when all aired episodes are completed
    calculate :actor_progress_status,
              WatchStatus,
              expr(
                cond do
                  actor_episodes_started_count == 0 -> :not_started
                  actor_aired_episodes_completed_count == aired_episodes_count -> :completed
                  true -> :in_progress
                end
              )

    # The aired episode Play starts for the actor, by its rank: the one they watched last while
    # they're in it, else the next aired one, else the first aired one
    calculate :actor_next_episode_rank,
              :integer,
              expr(
                cond do
                  is_nil(actor_last_watched_rank) ->
                    first_aired_rank

                  actor_last_watched_status != :completed ->
                    actor_last_watched_rank

                  true ->
                    first(episodes,
                      field: :rank,
                      query: [
                        filter: expr(aired? and rank > parent(actor_last_watched_rank)),
                        sort: [rank: :asc]
                      ]
                    ) || first_aired_rank
                end
              )

    # The share of the aired episodes the current user has completed, from 0 to 100
    calculate :actor_percent_watched,
              :float,
              expr(
                if aired_episodes_count == 0 do
                  0.0
                else
                  type(actor_aired_episodes_completed_count, :float) * 100.0 /
                    aired_episodes_count
                end
              )
  end

  aggregates do
    count :season_count, :episodes, field: :season_number, uniq?: true

    list :season_numbers, :episodes, :season_number do
      uniq? true
      sort season_number: :asc
    end

    exists :has_media?, :episodes do
      description "Whether a TV Show has videos for any of their episode"
      filter expr(has_media?)
    end

    count :aired_episodes_count, :episodes do
      filter expr(aired?)
    end

    count :aired_episodes_with_media_count, :episodes do
      filter expr(aired? and has_media?)
    end

    # Number of aired episodes that the current user has completed.
    # Only used for internal calculation
    count :actor_aired_episodes_completed_count, :episodes do
      filter expr(aired? and actor_progress_status == :completed)
      public? false
    end

    # Number of episodes that the current user has started.
    # Only used for internal calculation
    count :actor_episodes_started_count, :episodes do
      filter expr(actor_progress_status != :not_started)
      public? false
    end

    first :first_aired_rank, :episodes, :rank do
      filter expr(aired?)
      sort rank: :asc
      public? false
    end

    # The aired episode the actor watched last, the latest aired one on a tie
    first :actor_last_watched_rank, :episodes, :rank do
      filter expr(aired? and not is_nil(actor_last_watched_at))
      sort actor_last_watched_at: :desc, rank: :desc
      public? false
    end

    first :actor_last_watched_status, :episodes, :actor_progress_status do
      filter expr(aired? and not is_nil(actor_last_watched_at))
      sort actor_last_watched_at: :desc, rank: :desc
      public? false
    end

    # The date at which the user last watched an episode of this show.
    # Used internally for sorting the Recently Watched section
    max :actor_last_watched_at, [:episodes, :actor_progress], :updated_at do
      public? false
    end
  end

  identities do
    identity :unique_tmdb_id, [:tmdb_id]
    identity :unique_tvdb_id, [:tvdb_id]
  end

  defimpl String.Chars, for: __MODULE__ do
    def to_string(show) do
      case show.content do
        %Ash.NotLoaded{} ->
          "[Show] id:#{show.id}"

        %{original_title: title, release_date: %Date{year: year}} ->
          "[Show] #{title} (#{year})"

        %{original_title: title} ->
          "[Show] #{title}"
      end
    end
  end
end
