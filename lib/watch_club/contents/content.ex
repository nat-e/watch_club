defmodule WatchClub.Contents.Content do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Clubs.{Library, LibraryItem}

  alias WatchClub.Contents.{
    Book,
    ContentType,
    ContentView,
    ExternalIdSource,
    Movie,
    SearchContentType,
    TvShow
  }

  alias WatchClub.Contents.Calculations.GetContentImplementation
  alias WatchClub.Contents.Validations.LibrariesAcceptContentType

  import Ash.Expr

  postgres do
    table "contents"
    repo(WatchClub.Repo)
  end

  actions do
    defaults [:read]

    read :for_view do
      description "Read action that loads all data needed to build ContentViews"
      prepare build(load: [library_items: [:library, :added_by]])
    end

    create :create_movie do
      description "Fetches a Movie from TMDB and creates it in DB. Content and MovieLocalization will also be created"
      primary? true
      argument :tmdb_id, :integer, allow_nil?: false
      argument :library_ids, {:array, :uuid_v7}, allow_nil?: true

      change WatchClub.Contents.Changes.CreateOrUpdateMovie, only_when_valid?: true

      change WatchClub.Contents.Changes.SetLibraries,
        only_when_valid?: true,
        where: [present(:library_ids)]

      change load([:implementation])
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

      validate LibrariesAcceptContentType do
        only_when_valid? true
        message dgettext_noop("errors", "Library does not accept this content type")
      end

      change manage_relationship(:library_ids, :libraries, type: :append_and_remove)
      change load(library_items: [:library])
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
end
