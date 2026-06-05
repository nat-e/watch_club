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

    update :mark_read do
      description "Marks the Book as read for the current user"
      require_atomic? false
      change WatchClub.Contents.Changes.SetViewerProgressCompleted
      change {WatchClub.Contents.Changes.NotifyContentViewChanged, content_path: :content}
    end

    update :mark_not_read do
      description "Marks the Book as not read for the current user"
      require_atomic? false
      change WatchClub.Contents.Changes.DeleteViewerProgress
      change {WatchClub.Contents.Changes.NotifyContentViewChanged, content_path: :content}
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

    has_one :viewer_progress, WatchProgress do
      from_many? true
      filter expr(user_id == ^actor(:id))
    end
  end

  calculations do
    calculate :playable?, :boolean, expr(audiobooks_count > 0 or ebooks_count > 0)

    calculate :viewer_progress_status,
              WatchStatus,
              expr(
                cond do
                  is_nil(viewer_progress) -> :not_started
                  viewer_progress.completed -> :completed
                  true -> :in_progress
                end
              )
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
