defmodule WatchClub.Contents.Movie do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.{
    Calculations.ActorVideoToPlay,
    Calculations.VideosToPlay,
    Content,
    MovieLocalization
  }

  alias WatchClub.History.{WatchProgress, WatchStatus}
  alias WatchClub.MediaCatalog.{Part, Video}
  alias WatchClub.Shared.AnyFieldChanged

  postgres do
    table "movies"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :delete
    end
  end

  # The metadata a refresh overwrites
  @refreshed_fields [:backdrop_path]

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
    end

    attribute :backdrop_path, :string do
      allow_nil? true
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

    has_one :best_localization, MovieLocalization do
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
  end

  calculations do
    calculate :has_media?, :boolean, expr(exists(parts, true)) do
      description "Whether a Video holds one of its Parts."
    end

    calculate :videos_to_play, {:array, :struct}, VideosToPlay do
      description "The Videos to play for it, one after the other."
      constraints items: [instance_of: Video]
      public? true
    end

    calculate :actor_video_to_play, :struct, ActorVideoToPlay do
      description "The Video where the actor resumes it: the one holding their Part, else the first."
      constraints instance_of: Video
      public? true
    end

    calculate :actor_progress_status,
              WatchStatus,
              expr(
                cond do
                  is_nil(actor_progress) -> :not_started
                  actor_progress.completed -> :completed
                  true -> :in_progress
                end
              )

    # The date at which the current user has most recently watched this movie
    calculate :actor_last_watched_at, :utc_datetime_usec, expr(actor_progress.updated_at)
  end

  defimpl String.Chars, for: __MODULE__ do
    def to_string(movie) do
      case movie.content do
        %Ash.NotLoaded{} ->
          "[Movie] id:#{movie.id}"

        %{original_title: title, release_date: %Date{year: year}} ->
          "[Movie] #{title} (#{year})"

        %{original_title: title} ->
          "[Movie] #{title}"
      end
    end
  end
end
