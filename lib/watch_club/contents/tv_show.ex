defmodule WatchClub.Contents.TvShow do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.{Content, ContentView, TvShowEpisode, TvShowLocalization}
  alias WatchClub.History.WatchStatus
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse

  postgres do
    table "tv_shows"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:original_name, :tmdb_id, :tvdb_id]

      argument :localizations, {:array, :map}, allow_nil?: false, default: []
      argument :episodes, {:array, :map}, allow_nil?: false, default: []

      change manage_relationship(:localizations,
               type: :direct_control,
               use_identities: [:_primary_key, :unique_locale_per_tv_show]
             )

      change manage_relationship(:episodes,
               type: :direct_control,
               use_identities: [:_primary_key, :unique_position_per_tv_show]
             )
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:original_name, :tmdb_id, :tvdb_id]

      argument :localizations, {:array, :map}, allow_nil?: false, default: []
      argument :episodes, {:array, :map}, allow_nil?: false, default: []

      change manage_relationship(:localizations,
               type: :direct_control,
               use_identities: [:_primary_key, :unique_locale_per_tv_show]
             )

      change manage_relationship(:episodes,
               type: :direct_control,
               use_identities: [:_primary_key, :unique_position_per_tv_show]
             )
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

    # The next episode that the current user has not watched to completion
    # Episodes are automatically sorted by season/episode number so no need to sort here
    has_one :viewer_next_episode, TvShowEpisode do
      from_many? true
      filter expr(viewer_progress_status != :completed)
    end

    # The best localization based on the current user locale
    has_one :best_localization, TvShowLocalization do
      from_many? true
    end
  end

  calculations do
    # The progress status of the show for the current user
    # A show is completed when all known episodes are completed
    calculate :viewer_progress_status,
              WatchStatus,
              expr(
                cond do
                  viewer_episodes_started_count == 0 -> :not_started
                  viewer_episodes_completed_count == episodes_count -> :completed
                  true -> :in_progress
                end
              )
  end

  aggregates do
    exists :first_episode_available?, :episodes do
      filter expr(season_number == 1 and episode_number == 1 and playable?)
    end

    count :episodes_count, :episodes

    count :viewer_episodes_completed_count, :episodes do
      filter expr(viewer_progress_status == :completed)
    end

    count :viewer_episodes_started_count, :episodes do
      filter expr(viewer_progress_status != :not_started)
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
