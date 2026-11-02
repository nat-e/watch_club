defmodule WatchClub.Clubs.LibraryItem do
  @moduledoc """
  Join resource linking a `Content` to a club's `Library`.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.Checks.ActorIsClubMemberFilter
  alias WatchClub.Clubs.Library
  alias WatchClub.Clubs.LibraryItem.Actions.{AddContentToLibraries, RemoveContentFromLibraries}
  alias WatchClub.Clubs.Validations.LibraryAllowsContentType
  alias WatchClub.Contents.{Content, ContentIdentity}
  alias WatchClub.Contents.Preparations.FilterByContentIdentities

  import Ash.Expr

  postgres do
    table "library_items"
    repo WatchClub.Repo

    references do
      reference :library, on_delete: :delete
      reference :added_by, on_delete: :nilify
    end
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
      # Lets `remove_content_from_libraries` stream the items it destroys
      pagination keyset?: true, required?: false
    end

    read :by_identities do
      description "Returns all LibraryItems that match one of the provided ContentIdentity"
      argument :content_identities, {:array, ContentIdentity}, allow_nil?: false

      prepare {FilterByContentIdentities, content_path: [:content]}
    end

    read :for_library do
      pagination keyset?: true, required?: false, stable_sort: [:id]

      argument :library_id, :uuid_v7, allow_nil?: false

      filter expr(library_id == ^arg(:library_id))
    end

    create :create do
      primary? true
      accept [:content_id, :library_id]

      validate LibraryAllowsContentType do
        only_when_valid? true
        message dgettext_noop("errors", "Library does not allow this content type")
      end

      change relate_actor(:added_by)

      # Create the added_content feed event
      change WatchClub.ActivityFeed.Changes.CreateActivityFeedEvent
    end

    # Bulk add/remove a Content to/from several libraries at once
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
      authorize_if can_read(:library)
    end

    policy action_type(:read) do
      description "Only club members can read library items"
      authorize_if can_read(:library)
    end

    # Per-library access is enforced by the :create / :destroy these delegate to.
    policy action([:add_content_to_libraries, :remove_content_from_libraries]) do
      description "Any authenticated user may add or remove content to libraries they can access"
      authorize_if always()
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # Publish to the Club's content topic
    # We add :content_id and :content_identity in the metadata to make
    # it easy for subscribers to know which media this is related to
    publish_all :create, ["content", "club", [:club_id]],
      load: [content: [:type, :external_id_source, :external_id]],
      transform: &add_content_identity_to_metadata/1

    publish_all :destroy, ["content", "club", [:club_id]],
      load: [content: [:type, :external_id_source, :external_id]],
      transform: &add_content_identity_to_metadata/1

    defp add_content_identity_to_metadata(%Ash.Notifier.Notification{} = notification) do
      content = notification.data.content

      %{
        notification
        | metadata:
            notification.metadata
            |> Map.put(:content_identity, ContentIdentity.from_content(content))
            |> Map.put(:content_id, content.id)
      }
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

  calculations do
    # The ID of the Club. Needed for computing the pub_sub topic
    calculate :club_id, :uuid_v7, expr(library.club_id)
  end

  identities do
    identity :library_and_content, [:library_id, :content_id]
  end
end
