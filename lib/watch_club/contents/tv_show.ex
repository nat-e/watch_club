defmodule WatchClub.Contents.TvShow do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.{Content, TvShowEpisode, TvShowLocalization}
  alias WatchClub.History.WatchStatus

  postgres do
    table "tv_shows"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:original_name, :backdrop_path, :tmdb_id, :tvdb_id]

      argument :localizations, {:array, :map}, allow_nil?: false, default: []
      argument :episodes, {:array, :map}, allow_nil?: false, default: []

      change manage_relationship(:localizations,
               type: :direct_control,
               use_identities: [:_primary_key, :unique_locale_per_tv_show],
               on_missing: :ignore
             )

      change manage_relationship(:episodes,
               type: :direct_control,
               use_identities: [:_primary_key, :unique_position_per_tv_show],
               on_missing: :ignore
             )
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:original_name, :backdrop_path, :tmdb_id, :tvdb_id]

      argument :localizations, {:array, :map}
      argument :episodes, {:array, :map}

      change manage_relationship(:localizations,
               type: :direct_control,
               use_identities: [:_primary_key, :unique_locale_per_tv_show],
               on_missing: :ignore
             )

      change manage_relationship(:episodes,
               type: :direct_control,
               use_identities: [:_primary_key, :unique_position_per_tv_show],
               on_missing: :ignore
             )
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

    # The next aired episode that the current user has not watched to completion.
    # If all aired episodes have been watched, this returns the first one.
    has_one :actor_next_episode, TvShowEpisode do
      manual WatchClub.Contents.TvShow.ActorNextEpisode
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

    # The date at which the user last watched an episode of this show.
    # Used internally for sorting the Recently Watched section
    max :actor_last_watched_at, [:episodes, :actor_progress], :updated_at do
      public? false
    end
  end

  identities do
    identity :unique_content, [:id]
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
