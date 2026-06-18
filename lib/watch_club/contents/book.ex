defmodule WatchClub.Contents.Book do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Contents.Content
  alias WatchClub.History.{WatchProgress, WatchStatus}
  alias WatchClub.MediaCatalog.{Audiobook, Ebook}

  postgres do
    table "books"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy, create: [], update: []]
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

    attribute :hardcover_id, :integer do
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

    has_many :ebooks, Ebook
    has_many :audiobooks, Audiobook
    has_many :watch_progresses, WatchProgress

    has_one :actor_progress, WatchProgress do
      from_many? true
      filter expr(user_id == ^actor(:id))
    end
  end

  calculations do
    calculate :playable?, :boolean, expr(audiobooks_count > 0 or ebooks_count > 0)

    calculate :actor_progress_status,
              WatchStatus,
              expr(
                cond do
                  is_nil(actor_progress) -> :not_started
                  actor_progress.completed -> :completed
                  true -> :in_progress
                end
              )

    calculate :actor_last_watched_at, :utc_datetime, expr(actor_progress.updated_at)
  end

  aggregates do
    count :audiobooks_count, :audiobooks
    count :ebooks_count, :ebooks
  end

  identities do
    identity :unique_content, [:id]
    identity :unique_hardcover_id, [:hardcover_id]
  end

  defimpl String.Chars, for: __MODULE__ do
    def to_string(book) do
      case book.content do
        %Ash.NotLoaded{} ->
          "[Book] id:#{book.id}"

        %{original_title: title, release_date: %Date{year: year}} ->
          "[Book] #{title} (#{year})"

        %{original_title: title} ->
          "[Book] #{title}"
      end
    end
  end
end
