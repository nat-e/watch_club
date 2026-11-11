defmodule WatchClub.Contents.SportsEvent do
  @moduledoc """
  A Sports Event, such as a UFC event or a Formula 1 race, from sportarr.net.

  Its metadata is in English only, so it has no localizations. Like a Movie, it can
  have several Parts, such as its Prelims and its Main Card.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.{Calculations.ActorVideoToPlay, Calculations.VideosToPlay, Content}
  alias WatchClub.History.{WatchProgress, WatchStatus}
  alias WatchClub.MediaCatalog.{Part, Video}
  alias WatchClub.Shared.AnyFieldChanged

  postgres do
    table "sports_events"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :delete
    end
  end

  # The metadata a refresh overwrites
  @refreshed_fields [
    :title,
    :overview,
    :league_id,
    :league_name,
    :season,
    :venue,
    :starts_at,
    :poster_url,
    :backdrop_url
  ]

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

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :overview, :string do
      public? true
    end

    attribute :league_id, :string do
      public? true
      description "The league's Sportarr ID, such as lg-000079 for the UFC"
    end

    attribute :league_name, :string do
      public? true
    end

    attribute :season, :string do
      public? true
    end

    attribute :venue, :string do
      public? true
    end

    attribute :starts_at, :utc_datetime do
      public? true
    end

    attribute :poster_url, :string do
      public? true
    end

    attribute :backdrop_url, :string do
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

    # The Parts it has files for, in watching order
    has_many :parts, Part do
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
    calculate :has_media?, :boolean, expr(exists(parts, true))

    calculate :videos_to_play, {:array, :struct}, VideosToPlay do
      constraints items: [instance_of: Video]
      public? true
    end

    calculate :actor_video_to_play, :struct, ActorVideoToPlay do
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

    # The date at which the current user has most recently watched this event
    calculate :actor_last_watched_at, :utc_datetime_usec, expr(actor_progress.updated_at)
  end

  defimpl String.Chars, for: __MODULE__ do
    def to_string(event), do: "[Sports Event] #{event.title}"
  end
end
