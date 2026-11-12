defmodule WatchClub.Contents.TvShowEpisode do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.{
    Calculations.ActorVideoToPlay,
    Calculations.VideosToPlay,
    TvShow,
    TvShowEpisodeLocalization
  }

  alias WatchClub.History.{WatchProgress, WatchStatus}
  alias WatchClub.MediaCatalog.{Part, Video}
  alias WatchClub.Shared.AnyFieldChanged

  postgres do
    table "tv_show_episodes"
    repo WatchClub.Repo

    references do
      reference :tv_show, on_delete: :delete
    end
  end

  # The metadata a refresh overwrites
  @refreshed_fields [:air_date, :still_path, :runtime]

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:tv_show_id, :season_number, :episode_number | @refreshed_fields]
      upsert? true
      upsert_identity :unique_position_per_tv_show
      upsert_fields @refreshed_fields
      upsert_condition AnyFieldChanged.expr(@refreshed_fields)
    end

    read :for_show do
      description "Retrieves all episodes of a TV show for a given TMDB ID"
      argument :tmdb_id, :integer, allow_nil?: false

      filter expr(
               tv_show.content.external_id_source == :tmdb and
                 tv_show.content.external_id == ^arg(:tmdb_id)
             )

      prepare build(sort: [rank: :asc])
    end
  end

  preparations do
    prepare build(load: [:formatted_episode_number])

    # We don't default sort episodes by show / season / episode because
    # 1. It breaks has_one relationship that implement their custom sorting (ie, tv_show.actor_last_watched_episode)
    # 2. It can affect performance
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
    # provider has no date yet. See `aired?`.
    attribute :air_date, :date do
      allow_nil? true
      public? true
    end

    # The path to the still image (16/9)
    attribute :still_path, :string do
      allow_nil? true
      public? true
    end

    attribute :runtime, :integer do
      public? true
    end
  end

  relationships do
    belongs_to :tv_show, TvShow do
      allow_nil? false
    end

    has_many :localizations, TvShowEpisodeLocalization

    has_one :best_localization, TvShowEpisodeLocalization do
      from_many? true
    end

    has_many :parts, Part do
      description "Its Parts held by a Video, in order. Parts without a Video are left out."
      public? true
      filter expr(exists(videos, true))
      sort number: :asc
    end

    has_many :watch_progresses, WatchProgress

    has_one :actor_progress, WatchProgress do
      from_many? true
      filter expr(user_id == ^actor(:id))
    end

    # This is simply the next episode in the show, does not depend on the actor
    has_one :next_episode, __MODULE__ do
      description "Following episode in airing order within the same show; nil for the finale."
      allow_nil? true

      sort rank: :asc
      filter expr(tv_show_id == parent(tv_show_id) and rank > parent(rank))

      # This avoids having Ash trying to join on this episode's id
      no_attributes? true
      # Adds a LIMIT 1 since the filter returns many episodes
      from_many? true
    end

    has_many :playable_episodes_after, __MODULE__ do
      description "The following episodes with Media, in airing order within the same show."
      sort rank: :asc
      filter expr(tv_show_id == parent(tv_show_id) and rank > parent(rank) and has_media?)
      no_attributes? true
    end

    # This is simply the previous episode in the show, does not depend on the actor
    has_one :previous_episode, __MODULE__ do
      description "Previous episode in airing order within the same show; nil for the pilot."
      allow_nil? true

      sort rank: :desc
      filter expr(tv_show_id == parent(tv_show_id) and rank < parent(rank))

      # This avoids having Ash trying to join on this episode's id
      no_attributes? true
      # Adds a LIMIT 1 since the filter returns many episodes
      from_many? true
    end
  end

  calculations do
    # A displayable episode and season number, e.g. S01E01
    calculate :formatted_episode_number,
              :string,
              WatchClub.Contents.TvShowEpisode.Calculations.FormattedEpisodeNumber do
      public? true
    end

    # Its place in its TV Show, in season then episode order. Unique in the TV Show while episode
    # numbers stay under 100,000.
    calculate :rank, :integer, expr(season_number * 100_000 + episode_number)

    calculate :has_media?, :boolean, expr(exists(parts, true)) do
      description "Whether it has a Video to play."
    end

    calculate :videos_to_play, {:array, :struct}, VideosToPlay do
      description "The Videos to play for it, one after the other."
      constraints items: [instance_of: Video]
      public? true
    end

    calculate :actor_video_to_play, :struct, ActorVideoToPlay do
      description "The Video the actor plays to watch it: the one where they stopped, else the first."
      constraints instance_of: Video
      public? true
    end

    # Once its air date has passed. Only aired episodes can be marked as watched, and they decide
    # whether a TV Show is finished and how complete its Content Request is.
    calculate :aired?, :boolean, expr(not is_nil(air_date) and air_date <= today())

    calculate :actor_progress_status,
              WatchStatus,
              expr(
                cond do
                  is_nil(actor_progress) -> :not_started
                  actor_progress.completed -> :completed
                  true -> :in_progress
                end
              )

    # The date at which the current user has most recently watched this episode, or nil
    calculate :actor_last_watched_at, :utc_datetime_usec, expr(actor_progress.updated_at)
  end

  identities do
    identity :unique_position_per_tv_show, [:tv_show_id, :season_number, :episode_number]
  end

  @doc """
  Formats a season and an episode number as the conventional `S01E01` used across media tooling,
  also for a TV Show Episode WatchClub doesn't have yet.
  """
  def format_number(season_number, episode_number),
    do: "S#{pad(season_number)}E#{pad(episode_number)}"

  defp pad(number), do: number |> Integer.to_string() |> String.pad_leading(2, "0")

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
