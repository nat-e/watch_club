defmodule WatchClub.Lists.ListItem do
  @moduledoc """
  Join resource linking a `Content` to a user's `List`.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Lists,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Contents.{Content, ContentIdentity}
  alias WatchClub.Contents.Preparations.FilterByContentIdentities
  alias WatchClub.Lists.ContentList
  alias WatchClub.Lists.ListItem.Actions.AddContentToLists

  import Ash.Expr

  postgres do
    table "list_items"
    repo WatchClub.Repo

    references do
      reference :list, on_delete: :delete
      reference :content, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, create: [:content_id, :list_id]]

    read :by_identities do
      description "Returns all ListItems that match one of the provided ContentIdentity"
      argument :content_identities, {:array, ContentIdentity}, allow_nil?: false

      prepare {FilterByContentIdentities, content_path: [:content]}
    end

    read :for_list do
      pagination keyset?: true, required?: false, stable_sort: [:id]

      argument :list_id, :uuid_v7, allow_nil?: false

      filter expr(list_id == ^arg(:list_id))
    end

    # Bulk add a Content to several of the acting user's lists at once
    action :add_content_to_lists, :struct do
      constraints instance_of: Content
      argument :content_identity, ContentIdentity, allow_nil?: false
      argument :list_ids, {:array, :uuid_v7}, allow_nil?: false

      run AddContentToLists
    end
  end

  policies do
    policy action_type(:create) do
      description "Users can only add content to their own lists"
      authorize_if relates_to_actor_via([:list, :owner])
    end

    policy action_type([:read, :destroy]) do
      description "Users can only access list items in their own lists"
      authorize_if expr(list.owner_id == ^actor(:id))
    end

    # Per-list ownership is enforced by the :create this delegates to.
    policy action(:add_content_to_lists) do
      description "Any authenticated user may add content to lists they own"
      authorize_if always()
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # Publish to the owning User's topic.
    # We add :content_id and :content_identity in the metadata to make
    # it easy for subscribers to know which content this is related to.
    publish_all :create, ["user", [:owner_id]],
      load: [content: [:type, :external_id_source, :external_id]],
      transform: &add_content_identity_to_metadata/1

    publish_all :destroy, ["user", [:owner_id]],
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

    create_timestamp :created_at
  end

  relationships do
    belongs_to :list, ContentList do
      public? true
      allow_nil? false
    end

    belongs_to :content, Content do
      public? true
      allow_nil? false
    end
  end

  calculations do
    # The ID of the owning User. Needed for computing the pub_sub topic.
    calculate :owner_id, :uuid_v7, expr(list.owner_id)
  end

  identities do
    identity :list_and_content, [:list_id, :content_id]
  end
end
