defmodule WatchClub.Contents.Content do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Contents.{
    Book,
    ContentIdentity,
    ContentType,
    ExternalIdSource,
    Genre,
    LibrarySort,
    Movie,
    SearchContentType,
    SearchResultsPage,
    TvShow
  }

  alias WatchClub.History.WatchStatus
  alias WatchClub.MediaCatalog.Media

  alias WatchClub.Requests.ContentRequest

  alias WatchClub.Conversations.Conversation

  alias WatchClub.Contents.Calculations.{ActorNextMediasToPlay, GetContentImplementation}
  alias WatchClub.Contents.Preparations.{FilterByContentIdentities, FilterByTitle}

  import Ash.Expr

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

    read :in_library do
      description "The Content in the Library that matches every filter given, in the chosen order"

      argument :query, :string do
        description "Keeps the Content with a title that contains it, ignoring case and accents"
      end

      argument :type, ContentType

      argument :not_watched?, :boolean do
        allow_nil? false
        default false
        description "Hides the Content the actor has finished"
      end

      argument :genres, {:array, Genre} do
        allow_nil? false
        default []
        description "Keeps the Content that has any of these genres"
      end

      argument :decades, {:array, :integer} do
        allow_nil? false
        default []
        description "Keeps the Content from one of these decades, such as 1990 for the 1990s"
      end

      argument :original_languages, {:array, :string} do
        allow_nil? false
        default []
        description "Keeps the Content in one of these original languages"
      end

      argument :min_rating, :float do
        description "Keeps the Content rated at least this"
      end

      argument :recommended?, :boolean do
        allow_nil? false
        default false
        description "Keeps the Content other Users recommended to the actor"
      end

      argument :sort, LibrarySort, allow_nil?: false, default: LibrarySort.default()

      filter expr(has_media?)
      prepare FilterByTitle, where: present(:query)
      prepare build(filter: expr(type == ^arg(:type))), where: present(:type)

      prepare build(filter: expr(actor_progress_status != :completed)),
        where: argument_equals(:not_watched?, true)

      prepare build(filter: expr(intersects(genres, ^arg(:genres)))),
        where: argument_does_not_equal(:genres, [])

      prepare build(filter: expr(decade in ^arg(:decades))),
        where: argument_does_not_equal(:decades, [])

      prepare build(filter: expr(original_language in ^arg(:original_languages))),
        where: argument_does_not_equal(:original_languages, [])

      prepare build(filter: expr(rating >= ^arg(:min_rating))), where: present(:min_rating)

      prepare build(filter: expr(exists(actor_recommendations, true))),
        where: argument_equals(:recommended?, true)

      prepare build(sort: [added_to_library_at: :desc]),
        where: argument_equals(:sort, :recently_added)

      prepare build(sort: [rating: :desc_nils_last]), where: argument_equals(:sort, :best_rated)

      # Content without a release date goes last both ways
      prepare build(sort: [release_date: :desc_nils_last]), where: argument_equals(:sort, :newest)
      prepare build(sort: [release_date: :asc_nils_last]), where: argument_equals(:sort, :oldest)
      prepare build(sort: [localized_title_key: :asc]), where: argument_equals(:sort, :title)

      pagination keyset?: true, offset?: true, countable: true, required?: false
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
      # gates on the persisted `type`. Skips the TMDB response cache so the
      # refresh gets current data.
      change {WatchClub.Contents.Changes.CreateOrUpdateMovie, cache?: false},
        only_when_valid?: true,
        where: attribute_equals(:type, :movie)

      change {WatchClub.Contents.Changes.CreateOrUpdateTvShow, cache?: false},
        only_when_valid?: true,
        where: attribute_equals(:type, :tv_show)
    end

    action :search, :struct do
      constraints instance_of: SearchResultsPage

      argument :query, :string, allow_nil?: false

      argument :content_type, SearchContentType,
        allow_nil?: false,
        default: :movies_and_shows,
        description: "The only scope until books can be searched"

      argument :page, :integer, allow_nil?: false, default: 1

      argument :has_media?, :boolean,
        allow_nil?: false,
        default: false,
        description: "Searches the Library's titles instead of TMDB"

      run WatchClub.Contents.Actions.SearchContent
    end

    action :library_filter_options, :map do
      description "The genres, decades and original languages that Browse lets the actor filter by"

      constraints fields: [
                    genres: [type: {:array, Genre}, allow_nil?: false],
                    decades: [type: {:array, :integer}, allow_nil?: false],
                    original_languages: [type: {:array, :string}, allow_nil?: false]
                  ]

      run WatchClub.Contents.Actions.GetLibraryFilterOptions
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    publish_all :create, ["content", "global"]
    publish_all :update, ["content", "global"]
    publish_all :destroy, ["content", "global"]
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

    attribute :genres, {:array, Genre} do
      allow_nil? false
      default []
      public? true
    end

    attribute :rating, :float do
      public? true
      description "Nil for Books, and when too few people voted. See `Rating`."
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

    has_one :request, ContentRequest

    # The Conversations in which another User recommended it to the actor, the latest first. A
    # deleted User's recommendations don't count.
    has_many :actor_recommendations, Conversation do
      filter expr(
               exists(participants, user_id == ^actor(:id)) and not is_nil(recommended_by_id) and
                 recommended_by_id != ^actor(:id)
             )

      sort inserted_at: :desc
    end

    # Of its Movie, its TV Show Episodes or its Book
    has_many :medias, Media
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

    # The decade it came out in, such as 1990 for 1994
    calculate :decade,
              :integer,
              expr(fragment("(date_part('decade', ?) * 10)::integer", release_date))

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

  aggregates do
    # When it joined the Library
    min :added_to_library_at, :medias, :inserted_at
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
