defmodule WatchClub.Contents.Movie do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.{Content, MovieLocalization}
  alias WatchClub.History.{WatchProgress, WatchStatus}
  alias WatchClub.MediaCatalog.Video

  postgres do
    table "movies"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:backdrop_path]
      primary? true
      argument :localizations, {:array, :map}, allow_nil?: false

      change manage_relationship(:localizations,
               type: :direct_control,
               use_identities: [:_primary_key, :unique_locale_per_movie],
               on_missing: :ignore
             )
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:backdrop_path]
      argument :localizations, {:array, :map}

      change manage_relationship(:localizations,
               type: :direct_control,
               use_identities: [:_primary_key, :unique_locale_per_movie],
               on_missing: :ignore
             )
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

    has_many :videos, Video
    has_many :watch_progresses, WatchProgress

    has_one :actor_progress, WatchProgress do
      from_many? true
      filter expr(user_id == ^actor(:id))
    end
  end

  calculations do
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

    # The date at which the current user has most recently watched this movie
    calculate :actor_last_watched_at, :utc_datetime_usec, expr(actor_progress.updated_at)
  end

  aggregates do
    count :videos_count, :videos
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
