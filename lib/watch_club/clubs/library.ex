defmodule WatchClub.Clubs.Library do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Clubs.Checks.ActorIsClubMember
  alias WatchClub.Clubs.Checks.ActorIsClubMemberFilter
  alias WatchClub.Clubs.{Club, LibraryItem}
  alias WatchClub.Contents.{Content, ContentType}

  require Ash.Query

  postgres do
    table "libraries"
    repo(WatchClub.Repo)

    references do
      reference(:club, on_delete: :delete, on_update: :update)
    end
  end

  actions do
    defaults [:read, update: [:name]]

    read :by_club do
      argument :club_id, :uuid_v7, allow_nil?: false

      filter expr(club_id == ^arg(:club_id))
    end

    update :set_index do
      accept [:index]
    end

    create :create do
      primary? true
      accept [:club_id, :name, :content_type]

      change before_action(fn changeset, context ->
               club_id = Ash.Changeset.get_attribute(changeset, :club_id)

               max_index =
                 __MODULE__
                 |> Ash.Query.filter(club_id == ^club_id)
                 |> Ash.max!(:index, scope: context)

               new_index = (max_index || -1) + 1
               Ash.Changeset.force_change_attribute(changeset, :index, new_index)
             end)
    end

    destroy :destroy do
      require_atomic? false

      change after_action(fn _changeset, record, context ->
               case WatchClub.Clubs.reorder_libraries(
                      record.club_id,
                      %{},
                      scope: context
                    ) do
                 {:ok, _} -> {:ok, record}
                 {:error, _} -> {:ok, record}
               end
             end)
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
      message dgettext_noop("errors", "Library content type is required")
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 3, max_length: 30
    end

    attribute :content_type, ContentType do
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

    many_to_many :contents, Content, through: LibraryItem
  end
end
