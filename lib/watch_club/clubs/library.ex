defmodule WatchClub.Clubs.Library do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Clubs.Changes.{
    ReorderLibrariesAfterDestroy,
    SetDefaultLibraryIcon,
    SetNextLibraryIndex
  }

  alias WatchClub.Clubs.Checks.ActorIsClubMember
  alias WatchClub.Clubs.Checks.ActorIsClubMemberFilter
  alias WatchClub.Clubs.{Club, LibraryIcon, LibraryItem}
  alias WatchClub.Contents.{Content, ContentType}

  import Ash.Expr

  postgres do
    table "libraries"
    repo(WatchClub.Repo)

    references do
      reference(:club, on_delete: :delete, on_update: :update)
    end
  end

  actions do
    defaults [:read]

    read :by_club do
      argument :club_id, :uuid_v7, allow_nil?: false

      filter expr(club_id == ^arg(:club_id))
    end

    update :set_index do
      accept [:index]
    end

    update :update do
      primary? true
      accept [:name, :icon]
    end

    create :create do
      primary? true
      accept [:club_id, :name, :content_type]

      change SetDefaultLibraryIcon
      change SetNextLibraryIndex
    end

    destroy :destroy do
      # Destroying a library reorders sibling libraries after deletion,
      # which performs follow-up updates across multiple records.
      require_atomic? false

      change ReorderLibrariesAfterDestroy
    end
  end

  policies do
    policy actor_absent() do
      description "Library actions must have an actor"
      forbid_if always()
    end

    policy action([:update, :destroy, :set_index]) do
      description "Only club admins can manage libraries"
      authorize_if {ActorIsClubMember, role: :admin}
    end

    policy action(:create) do
      description "Only club admins can manage libraries"
      authorize_if {ActorIsClubMember, role: :admin}
    end

    policy action(:by_club) do
      description "Only club members can list club libraries"
      authorize_if ActorIsClubMember
    end

    policy action(:read) do
      description "Only club members can read library"
      authorize_if ActorIsClubMemberFilter
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    publish :create, ["clubs", :club_id]
    publish :update, ["clubs", :club_id]
    publish :set_index, ["clubs", :club_id]
    publish :destroy, ["clubs", :club_id]
  end

  preparations do
    prepare build(sort: [club_id: :asc, index: :asc, inserted_at: :asc])
  end

  validations do
    # Customer-facing validations own localized messages for form errors.
    # Keep shape rules here instead of duplicating them as attribute constraints.
    validate present(:name) do
      message dgettext_noop("errors", "Library name is required")
    end

    validate string_length(:name, min: 3) do
      message dgettext_noop("errors", "Library name must be at least %{min} characters")
    end

    validate string_length(:name, max: 30) do
      message dgettext_noop("errors", "Library name cannot be longer than %{max} characters")
    end

    validate present(:content_type) do
      where action_is(:create)
      message dgettext_noop("errors", "Library content type is required")
    end

    validate one_of(:icon, LibraryIcon.names()) do
      message dgettext_noop("errors", "Library icon is invalid")
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :content_type, ContentType do
      allow_nil? false
      public? true
    end

    attribute :icon, :string do
      allow_nil? false
      public? true
    end

    attribute :index, :integer do
      allow_nil? false
      public? true
      default 0
    end

    timestamps()
  end

  relationships do
    belongs_to :club, Club do
      public? true
      allow_nil? false
    end

    has_many :items, LibraryItem do
      public? true
      sort inserted_at: :desc
    end

    many_to_many :contents, Content, through: LibraryItem
  end
end
