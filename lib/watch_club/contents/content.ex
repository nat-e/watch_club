defmodule WatchClub.Contents.Content do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  require Ash.Query

  alias WatchClub.Contents.{
    Book,
    ContentIdentity,
    ContentType,
    ExternalIdSource,
    Genre,
    LibrarySort,
    Movie,
    SearchContentType,
    SearchResult,
    SearchResultsPage,
    SportsEvent,
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

    read :by_content_identity do
      argument :content_identity, ContentIdentity, allow_nil?: false

      prepare FilterByContentIdentities
    end

    read :by_content_identities do
      argument :content_identities, {:array, ContentIdentity}, allow_nil?: false

      prepare FilterByContentIdentities
    end

    read :in_library do
      description "The Content in the Library that matches every filter given, in the chosen order"

      argument :query, :string do
        description "Keeps the Content with a title that contains each of its words, in any order, ignoring case and accents"
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

    read :new_in_library do
      description "The Content of one scope in the Library, the latest added first. A requested one waits until its Content Request is Completed."

      argument :content_type, SearchContentType, allow_nil?: false, default: :movies_and_shows

      filter expr(has_media? and not exists(request, not completed?))

      prepare fn query, _context ->
                types =
                  SearchContentType.content_types(Ash.Query.get_argument(query, :content_type))

                Ash.Query.filter(query, type in ^types)
              end,
              only_when_valid?: true

      prepare build(sort: [added_to_library_at: :desc, id: :desc])
    end

    read :user_recently_watched do
      description "The actor's Content in progress that is Ready to Play, the most recently watched first. Not limited: there are few."

      prepare build(
                filter: [actor_progress_status: :in_progress],
                sort: [actor_last_watched_at: :desc]
              )

      # Ready to Play is computed in Elixir, after the query: a limit would apply before it
      prepare fn query, context ->
        Ash.Query.after_action(query, fn _query, contents ->
          {:ok,
           contents
           |> Ash.load!(:actor_next_medias_to_play, Ash.Context.to_opts(context))
           |> Enum.reject(&(&1.actor_next_medias_to_play == []))}
        end)
      end
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

      change WatchClub.Contents.Changes.CreateOrUpdateSportsEvent,
        only_when_valid?: true,
        where: attribute_equals(:type, :sports_event)

      change load([:implementation])
    end

    update :refresh_metadata do
      description "Fetches current metadata and updates Content and its relations in place"
      require_atomic? false

      change WatchClub.Contents.Changes.CreateOrUpdateMovie,
        only_when_valid?: true,
        where: attribute_equals(:type, :movie)

      change WatchClub.Contents.Changes.CreateOrUpdateTvShow,
        only_when_valid?: true,
        where: attribute_equals(:type, :tv_show)

      change WatchClub.Contents.Changes.CreateOrUpdateSportsEvent,
        only_when_valid?: true,
        where: attribute_equals(:type, :sports_event)
    end

    action :get_or_refresh, :struct do
      description """
      Returns stored Content, creating it when missing and refreshing metadata older than max_age
      when the Metadata Provider answers. Concurrent calls for the same Content share one fetch.
      A Metadata Provider failure returns the stored Content, or an error when none is stored.
      """

      constraints instance_of: __MODULE__
      argument :content_identity, ContentIdentity, allow_nil?: false

      argument :max_age, :term do
        allow_nil? false
        default 24 * 60 * 60

        description "Maximum metadata age in seconds from this call; :infinity never refreshes stored Content"
      end

      validate fn input, _context ->
        case input.arguments.max_age do
          :infinity -> :ok
          seconds when is_integer(seconds) and seconds >= 0 -> :ok
          _ -> {:error, field: :max_age, message: "must be non-negative seconds or :infinity"}
        end
      end

      run WatchClub.Contents.Actions.GetOrRefreshContent
    end

    action :search, :struct do
      constraints instance_of: SearchResultsPage

      argument :query, :string, allow_nil?: false

      argument :content_type, SearchContentType, allow_nil?: false, default: :movies_and_shows

      argument :type, ContentType,
        description:
          "Keeps only this Content Type of the scope, such as the Movies among Movies and TV Shows"

      argument :page, :integer, allow_nil?: false, default: 1

      argument :has_media?, :boolean,
        allow_nil?: false,
        default: false,
        description: "Searches the Library's titles instead of the Metadata Provider"

      validate fn input, _context ->
        type = input.arguments[:type]

        if is_nil(type) or type in SearchContentType.content_types(input.arguments.content_type),
          do: :ok,
          else: {:error, field: :type, message: "must be a Content Type of the search's scope"}
      end

      run WatchClub.Contents.Actions.SearchContent
    end

    action :look_up, :struct do
      description "The Movie, TV Show or Sports Event with this ID, as a search result, without saving it. nil when its Metadata Provider has none."
      constraints instance_of: SearchResult
      allow_nil? true

      argument :content_identity, ContentIdentity, allow_nil?: false

      run WatchClub.Contents.Actions.LookUpContent
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
      public? true
      description "Nil when the Metadata Provider doesn't say, as for Sports Events"
    end

    attribute :origin_country, :string do
      public? true
      description "Nil when the Metadata Provider doesn't say, as for some Sports Events"
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

    attribute :metadata_refreshed_at, :utc_datetime_usec do
      description "The last successful metadata refresh; nil means it has not been refreshed"
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

    has_one :sports_event, SportsEvent do
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

    # Of its Movie, its TV Show Episodes, its Book or its Sports Event
    has_many :medias, Media
  end

  calculations do
    # Typed as a plain :struct (one of Book | Movie | TvShow | SportsEvent), not :union:
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
                  type == :sports_event -> sports_event.has_media?
                end
              )

    # An Incomplete TV Show: in the Library, with an aired TV Show Episode without Media
    calculate :incomplete?,
              :boolean,
              expr(
                type == :tv_show and tv_show.has_media? and
                  tv_show.aired_episodes_with_media_count < tv_show.aired_episodes_count
              )

    # The progress status of the content for the current user
    calculate :actor_progress_status,
              WatchStatus,
              expr(
                cond do
                  type == :book -> book.actor_progress_status
                  type == :movie -> movie.actor_progress_status
                  type == :tv_show -> tv_show.actor_progress_status
                  type == :sports_event -> sports_event.actor_progress_status
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
                  type == :sports_event -> sports_event.actor_last_watched_at
                end
              )

    calculate :actor_next_medias_to_play,
              {:array, :struct},
              ActorNextMediasToPlay do
      description "What Play opens for the actor: the Video to resume, or a Book's Audiobooks and Ebooks."
    end

    # The decade it came out in, such as 1990 for 1994
    calculate :decade,
              :integer,
              expr(fragment("(date_part('decade', ?) * 10)::integer", release_date))

    # What pages show of a Content: a Movie's or a TV Show's from its localization in the
    # actor's Locale, a Sports Event's from its own English metadata. Images are TMDB paths, or
    # image URLs for a Sports Event.
    calculate :title,
              :string,
              expr(
                cond do
                  type == :movie ->
                    fragment("coalesce(?, ?)", movie.best_localization.title, original_title)

                  type == :tv_show ->
                    fragment("coalesce(?, ?)", tv_show.best_localization.title, original_title)

                  type == :sports_event ->
                    sports_event.title

                  true ->
                    original_title
                end
              ) do
      public? true
      allow_nil? false
    end

    calculate :overview,
              :string,
              expr(
                cond do
                  type == :movie -> movie.best_localization.overview
                  type == :tv_show -> tv_show.best_localization.overview
                  type == :sports_event -> sports_event.overview
                end
              ) do
      public? true
    end

    calculate :poster_path,
              :string,
              expr(
                cond do
                  type == :movie -> movie.best_localization.poster_path
                  type == :tv_show -> tv_show.best_localization.poster_path
                  type == :sports_event -> sports_event.poster_url
                end
              ) do
      public? true
    end

    calculate :backdrop_path,
              :string,
              expr(
                cond do
                  type == :movie -> movie.backdrop_path
                  type == :tv_show -> tv_show.backdrop_path
                  type == :sports_event -> sports_event.backdrop_url
                end
              ) do
      public? true
    end

    calculate :localized_title_key, :string, expr(fragment("trim(unaccent(lower(?)))", title)) do
      public? true
      allow_nil? false
    end
  end

  aggregates do
    # When it joined the Library
    min :added_to_library_at, :medias, :inserted_at
  end

  identities do
    identity :external_id, [:type, :external_id_source, :external_id]
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
