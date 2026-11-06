defmodule WatchClub.Playlists.PlaylistItem do
  @moduledoc """
  One `Content` in a `Playlist`, with who added it and when. It stays when that User loses their
  Playlist Access or is deleted.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Playlists,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.Changes.EnsureContentExists
  alias WatchClub.Contents.{Content, ContentIdentity}
  alias WatchClub.Playlists.Playlist

  postgres do
    table "playlist_items"
    repo WatchClub.Repo

    references do
      reference :playlist, on_delete: :delete
      reference :content, on_delete: :delete
      reference :added_by, on_delete: :nilify
    end
  end

  actions do
    defaults [:read, :destroy]

    read :for_playlist do
      description "Newest added first"
      argument :playlist_id, :uuid_v7, allow_nil?: false

      pagination keyset?: true, required?: false

      filter expr(playlist_id == ^arg(:playlist_id))
      prepare build(sort: [added_at: :desc])
    end

    create :add do
      description "Add to Playlist. Creates the Content from its Metadata Provider when WatchClub doesn't have it yet."
      accept [:playlist_id]
      argument :content_identity, ContentIdentity, allow_nil?: false

      # EnsureContentExists creates the Content before the transaction, and the policy checks
      # the new Playlist Item once it's inserted
      allow_post_action_authorization? true

      change relate_actor(:added_by)
      change EnsureContentExists
    end
  end

  policies do
    policy action_type(:read) do
      description "Whoever sees its Playlist sees it"
      authorize_if can_read(:playlist)
    end

    policy action_type([:create, :destroy]) do
      description "The Playlist's owner and the Users with Edit access add and remove its Content"
      authorize_if expr(playlist.editable_by?(user_id: ^actor(:id)))
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # Everyone who sees the Playlist
    publish_all :create, ["playlist", :playlist_id]
    publish_all :destroy, ["playlist", :playlist_id]
  end

  attributes do
    uuid_v7_primary_key :id

    create_timestamp :added_at
  end

  relationships do
    belongs_to :playlist, Playlist do
      public? true
      allow_nil? false
    end

    # Set by EnsureContentExists from the action arguments, not accepted
    belongs_to :content, Content do
      public? true
      allow_nil? false
    end

    belongs_to :added_by, User do
      attribute_writable? false
    end
  end

  identities do
    identity :playlist_and_content, [:playlist_id, :content_id]
  end
end
