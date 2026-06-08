defmodule WatchClub.Contents.Content do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer,
    notifiers: [WatchClub.Contents.Notifiers.ContentChangedNotifier]

  alias WatchClub.Clubs.{Library, LibraryItem}

  alias WatchClub.Contents.{
    Book,
    ContentIdentity,
    ContentType,
    ContentView,
    ExternalIdSource,
    Movie,
    SearchContentType,
    TvShow
  }

  alias WatchClub.History.WatchStatus

  alias WatchClub.Requests.ContentRequest

  alias WatchClub.Contents.Calculations.GetContentImplementation

  import Ash.Expr
  require Ash.Query

  postgres do
    table "contents"
    repo WatchClub.Repo
  end

  actions do
    defaults [:read]

    read :for_view do
      description "Read action that loads all data needed to build ContentViews for the current user"

      prepare build(
                load: [
                  :viewer_progress_status,
                  library_items: [:library, :added_by],
                  viewer_request: [:status, :status_group, :progress],
                  book: [:audiobooks, :ebooks, :playable?],
                  movie: [:videos, :playable?],
                  tv_show: [
                    :viewer_next_episode,
                    episodes: [:videos, :playable?, :viewer_progress_status]
                  ]
                ]
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

      change WatchClub.Contents.Changes.CreateContentNotification
    end

    action :search, {:array, :struct} do
      constraints items: [instance_of: ContentView]

      argument :query, :string, allow_nil?: false
      argument :content_type, SearchContentType, allow_nil?: false
      argument :location, :uuid_v7, allow_nil?: true

      run WatchClub.Contents.Actions.SearchContent
    end

    update :set_libraries do
      description "Update the list of libraries a content belongs to"

      # Setting libraries validates selected libraries and manages join records,
      # so this action intentionally coordinates related data.
      require_atomic? false
      argument :library_ids, {:array, :uuid_v7}, allow_nil?: false

      # Keep relationship authorization enabled: this action syncs the actor's
      # selected libraries, not the content's global library list. Omitted library
      # items outside the actor's removal rights are preserved.
      change fn changeset, _context ->
        case Ash.Changeset.get_argument(changeset, :library_ids) do
          nil ->
            changeset

          library_ids ->
            library_inputs =
              Enum.map(library_ids, fn library_id ->
                %{id: library_id, content_id: changeset.data.id, library_id: library_id}
              end)

            Ash.Changeset.manage_relationship(changeset, :libraries, library_inputs,
              type: :append_and_remove,
              join_keys: [:content_id, :library_id],
              meta: [id: :library_ids]
            )
        end
      end

      change load(library_items: [:library])
      change WatchClub.Contents.Changes.CreateContentNotification
    end
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

    has_one :viewer_request, ContentRequest do
      from_many? true
      filter expr(user_id == ^actor(:id))
    end

    has_many :library_items, LibraryItem
    many_to_many :libraries, Library, through: LibraryItem
  end

  calculations do
    calculate :implementation, :union, GetContentImplementation do
      constraints types: [
                    book: [type: :struct, constraints: [instance_of: Book]],
                    movie: [type: :struct, constraints: [instance_of: Movie]],
                    tv_show: [type: :struct, constraints: [instance_of: TvShow]]
                  ]

      allow_nil? false
    end

    # The progress status of the content for the current user
    calculate :viewer_progress_status,
              WatchStatus,
              expr(
                cond do
                  type == :book -> book.viewer_progress_status
                  type == :movie -> movie.viewer_progress_status
                  type == :tv_show -> tv_show.viewer_progress_status
                end
              )

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
