defmodule WatchClub.Contents.Content do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Clubs.{Library, LibraryItem}

  alias WatchClub.Contents.{
    Book,
    ContentIdentity,
    ContentType,
    ExternalIdSource,
    Movie,
    SearchContentType,
    TvShow
  }

  alias WatchClub.History.WatchStatus

  alias WatchClub.Requests.ContentRequest

  alias WatchClub.Contents.Calculations.{ActorNextMediasToPlay, GetContentImplementation}
  alias WatchClub.Contents.Preparations.FilterByContentIdentities

  import Ash.Expr
  require Ash.Query

  postgres do
    table "contents"
    repo WatchClub.Repo
  end

  actions do
    defaults [:read]

    read :by_content_identities do
      argument :content_identities, {:array, ContentIdentity}, allow_nil?: false

      prepare FilterByContentIdentities
    end

    read :user_recently_watched do
      description "Returns the Contents recently watched by the actor. Most recently watched content first"

      prepare build(
                filter: [actor_progress_status: :in_progress],
                sort: [actor_last_watched_at: :desc]
              )
    end

    create :create do
      description "Fetches content from an external metadata provider (TMDB, Hardcover, ...) and creates the Content and its relations"
      primary? true
      upsert? true
      upsert_identity :external_id
      argument :content_identity, ContentIdentity, allow_nil?: false

      # Seed the Content's identity attributes from the argument so the
      # type-gated changes below (and the upsert identity) can rely on them.
      change fn changeset, _context ->
        identity = Ash.Changeset.get_argument(changeset, :content_identity)

        changeset
        |> Ash.Changeset.force_change_attribute(:type, identity.type)
        |> Ash.Changeset.force_change_attribute(:external_id_source, identity.external_id_source)
        |> Ash.Changeset.force_change_attribute(:external_id, identity.external_id)
      end

      change WatchClub.Contents.Changes.CreateOrUpdateMovie,
        only_when_valid?: true,
        where: attribute_equals(:type, :movie)

      change WatchClub.Contents.Changes.CreateOrUpdateTvShow,
        only_when_valid?: true,
        where: attribute_equals(:type, :tv_show)

      change load([:implementation])
    end

    update :refresh_metadata do
      description "Re-fetches content from an external metadata provider (TMDB, Hardcover, ...) and updates the content and its relations"
      require_atomic? false

      # Identity is already on the Content being refreshed, so each change
      # gates on the persisted `type`.
      change WatchClub.Contents.Changes.CreateOrUpdateMovie,
        only_when_valid?: true,
        where: attribute_equals(:type, :movie)

      change WatchClub.Contents.Changes.CreateOrUpdateTvShow,
        only_when_valid?: true,
        where: attribute_equals(:type, :tv_show)
    end

    action :search, {:array, :struct} do
      argument :query, :string, allow_nil?: false
      argument :content_type, SearchContentType, allow_nil?: false
      argument :location, :uuid_v7, allow_nil?: true

      run WatchClub.Contents.Actions.SearchContent
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    publish_all :create, ["content", "global"]
    publish_all :update, ["content", "global"]
    publish_all :destroy, ["content", "global"]
  end

  preparations do
    prepare build(load: [:implementation])
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :type, ContentType do
      allow_nil? false
      public? true
    end

    attribute :external_id_source, ExternalIdSource do
      allow_nil? false
      public? true
    end

    attribute :external_id, :string do
      allow_nil? false
      public? true
    end

    attribute :original_title, :string do
      allow_nil? false
      public? true
    end

    attribute :original_language, :string do
      allow_nil? false
      public? true
    end

    attribute :origin_country, :string do
      allow_nil? false
      public? true
    end

    attribute :release_date, :date do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  relationships do
    has_one :book, Book do
      destination_attribute :id
    end

    has_one :movie, Movie do
      destination_attribute :id
    end

    has_one :tv_show, TvShow do
      destination_attribute :id
    end

    has_many :requests, ContentRequest

    has_one :actor_request, ContentRequest do
      from_many? true
      filter expr(user_id == ^actor(:id))
    end

    has_many :library_items, LibraryItem
    many_to_many :libraries, Library, through: LibraryItem
  end

  calculations do
    # Typed as a plain :struct (one of Book | Movie | TvShow), not :union:
    # union calculation values get wrapped in %Ash.Union{} on load, and
    # callers want the implementation struct directly.
    calculate :implementation, :struct, GetContentImplementation do
      allow_nil? false
      # Load is a Keyword list of one load term per content type
      argument :load, :term
    end

    # Whether or not there are Video, Audiobook or Ebooks to back this Content in the media center
    # For TV Show, this will be true as soon as the media
    calculate :has_media?,
              :boolean,
              expr(
                cond do
                  type == :book -> book.has_media?
                  type == :movie -> movie.has_media?
                  type == :tv_show -> tv_show.has_media?
                end
              )

    # The progress status of the content for the current user
    calculate :actor_progress_status,
              WatchStatus,
              expr(
                cond do
                  type == :book -> book.actor_progress_status
                  type == :movie -> movie.actor_progress_status
                  type == :tv_show -> tv_show.actor_progress_status
                end
              )

    # The date at which the current user has most recently watched this content
    calculate :actor_last_watched_at,
              :utc_datetime_usec,
              expr(
                cond do
                  type == :book -> book.actor_last_watched_at
                  type == :movie -> movie.actor_last_watched_at
                  type == :tv_show -> tv_show.actor_last_watched_at
                end
              )

    calculate :actor_next_medias_to_play,
              {:array, :struct},
              ActorNextMediasToPlay

    calculate :localized_title_key,
              :string,
              expr(
                cond do
                  type == :movie ->
                    fragment(
                      "trim(unaccent(lower(coalesce(?, ?))))",
                      movie.best_localization.title,
                      original_title
                    )

                  type == :tv_show ->
                    fragment(
                      "trim(unaccent(lower(coalesce(?, ?))))",
                      tv_show.best_localization.title,
                      original_title
                    )

                  true ->
                    fragment("trim(unaccent(lower(?)))", original_title)
                end
              ) do
      public? true
      allow_nil? false
    end
  end

  identities do
    identity :external_id, [:external_id_source, :external_id]
  end

  defimpl String.Chars, for: __MODULE__ do
    def to_string(%{type: type, original_title: title, release_date: %Date{year: year}}) do
      "[#{ContentType.label(type)}] #{title} (#{year})"
    end

    def to_string(%{type: type, original_title: title}) do
      "[#{ContentType.label(type)}] #{title}"
    end
  end
end
