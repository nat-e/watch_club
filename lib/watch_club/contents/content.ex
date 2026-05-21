defmodule WatchClub.Contents.Content do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

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

  import Ash.Expr

  postgres do
    table "contents"
    repo WatchClub.Repo
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

    create :create_tv_show do
      description "Fetches a TV Show from TMDB and creates it in DB. Content, TvShowLocalization, and TV Show Episodes will also be created"
      argument :tmdb_id, :integer, allow_nil?: false
      argument :library_ids, {:array, :uuid_v7}, allow_nil?: true

      change WatchClub.Contents.Changes.CreateOrUpdateTvShow, only_when_valid?: true

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

      # Keep relationship authorization enabled: this action syncs the actor's
      # selected libraries, not the content's global library list. Omitted library
      # items outside the actor's removal rights are preserved.
      change fn changeset, _context ->
        library_inputs =
          changeset
          |> Ash.Changeset.get_argument(:library_ids)
          |> Enum.map(fn library_id ->
            %{id: library_id, content_id: changeset.data.id, library_id: library_id}
          end)

        Ash.Changeset.manage_relationship(changeset, :libraries, library_inputs,
          type: :append_and_remove,
          join_keys: [:content_id, :library_id],
          meta: [id: :library_ids]
        )
      end

      change load(library_items: [:library])
    end
  end

  policies do
    policy actor_absent() do
      description "Content actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action([:read, :for_view, :search]) do
      description "Content metadata is visible to authenticated users"
      authorize_if always()
    end

    policy action([:create_movie, :create_tv_show]) do
      description "Authenticated users can create catalog content and only select libraries they can access"
      authorize_if WatchClub.Contents.Checks.ActorCanAccessSelectedLibraries
    end

    policy action(:set_libraries) do
      description "Users can only set content libraries they can access"
      authorize_if WatchClub.Contents.Checks.ActorCanAccessSelectedLibraries
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
