defmodule WatchClub.Clubs.LibraryItem do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [WatchClub.Contents.Notifiers.ContentChangedNotifier]

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.Checks.{ActorCanCreateLibraryItem, ActorIsClubMemberFilter}
  alias WatchClub.Clubs.Library
  alias WatchClub.Clubs.LibraryItem.Actions.{AddContentToLibraries, RemoveContentFromLibraries}
  alias WatchClub.Clubs.LibraryItemsSortOption
  alias WatchClub.Clubs.Preparations.PrepareLibraryItemsForView
  alias WatchClub.Clubs.Validations.LibraryAllowsContentType
  alias WatchClub.Contents.{Content, ContentIdentity}
  alias WatchClub.Shared.SortOrder

  import Ash.Expr

  postgres do
    table "library_items"
    repo WatchClub.Repo

    references do
      reference :library, on_delete: :delete, on_update: :update
      reference :added_by, on_delete: :nilify, on_update: :update
    end
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
    end

    read :for_library do
      pagination keyset?: true, required?: false, stable_sort: [:id]

      argument :library_id, :uuid_v7, allow_nil?: false

      argument :sort_by, LibraryItemsSortOption do
        allow_nil? false
        default LibraryItemsSortOption.default_option()
      end

      argument :sort_order, SortOrder do
        allow_nil? false
        default LibraryItemsSortOption.default_order()
      end

      filter expr(library_id == ^arg(:library_id))

      prepare PrepareLibraryItemsForView
    end

    create :create do
      primary? true
      accept [:content_id, :library_id]

      validate LibraryAllowsContentType do
        only_when_valid? true
        message dgettext_noop("errors", "Library does not allow this content type")
      end

      change relate_actor(:added_by)
    end

    # Bulk add/remove a Content to/from several libraries at once, emitting a
    # single content_changed notification (vs one per LibraryItem). Each row
    # still goes through :create / :destroy, so per-library validation and
    # policies apply.
    action :add_content_to_libraries, :struct do
      constraints instance_of: Content
      argument :content_identity, ContentIdentity, allow_nil?: false
      argument :library_ids, {:array, :uuid_v7}, allow_nil?: false

      run AddContentToLibraries
    end

    action :remove_content_from_libraries, :struct do
      constraints instance_of: Content
      argument :content_identity, ContentIdentity, allow_nil?: false
      argument :library_ids, {:array, :uuid_v7}, allow_nil?: false

      run RemoveContentFromLibraries
    end
  end

  policies do
    policy actor_absent() do
      description "Library items actions must have an actor"
      access_type :strict
      forbid_if always()
    end

    policy action([:destroy]) do
      description "Only admins or current members that have added the content can remove it"
      authorize_if {ActorIsClubMemberFilter, role: :admin, club_path: [:library, :club]}

      authorize_if expr(
                     added_by_id == ^actor(:id) and
                       exists(library.club.memberships, user_id == ^actor(:id))
                   )
    end

    policy action([:create]) do
      description "Only club members can create library items"
      authorize_if ActorCanCreateLibraryItem
    end

    policy action([:read, :for_library]) do
      description "Only club members can read library items"
      authorize_if {ActorIsClubMemberFilter, club_path: [:library, :club]}
    end

    # Per-library access is enforced by the :create / :destroy these delegate to.
    policy action([:add_content_to_libraries, :remove_content_from_libraries]) do
      description "Any authenticated user may add or remove content to libraries they can access"
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id

    timestamps()
  end

  relationships do
    belongs_to :library, Library do
      public? true
      allow_nil? false
    end

    belongs_to :content, Content do
      public? true
      allow_nil? false
    end

    belongs_to :added_by, User do
      public? true
    end
  end

  identities do
    identity :library_and_content, [:library_id, :content_id]
  end
end
