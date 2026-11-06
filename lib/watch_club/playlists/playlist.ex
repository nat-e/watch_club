defmodule WatchClub.Playlists.Playlist do
  @moduledoc """
  A named collection of `Content` owned by one `User`, private until they share it with other
  Users, giving each View or Edit `PlaylistAccess`. A new User starts with To Watch.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Playlists,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.ContentIdentity
  alias WatchClub.Playlists.Playlist.Calculations.HoldsContent
  alias WatchClub.Playlists.{PlaylistAccess, PlaylistItem}
  alias WatchClub.Shared.LucideIcon

  postgres do
    table "playlists"
    repo WatchClub.Repo

    references do
      reference :owner, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, update: [:name, :icon]]

    create :create do
      primary? true
      accept [:name, :icon]

      change relate_actor(:owner)
    end

    update :share do
      description "Gives each User in `accesses` their Playlist Access, and takes it from the others"
      require_atomic? false

      argument :accesses, {:array, :map} do
        allow_nil? false
        description "`%{user_id, level}` for each User the Playlist is shared with"
      end

      change manage_relationship(:accesses,
               type: :direct_control,
               use_identities: [:playlist_and_user],
               on_match: {:update, :update}
             )
    end
  end

  policies do
    policy action_type(:create) do
      description "Users create their own Playlists"
      authorize_if relating_to_actor(:owner)
    end

    policy action_type(:read) do
      description "Its owner and the Users it's shared with see it"
      authorize_if relates_to_actor_via(:owner)
      authorize_if relates_to_actor_via([:accesses, :user])
    end

    policy action_type([:update, :destroy]) do
      description "Only its owner renames, shares or deletes it"
      authorize_if relates_to_actor_via(:owner)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # The owner's pages subscribe to the topic of their new Playlist
    publish_all :create, ["user", :owner_id]
    # Everyone who sees the Playlist
    publish_all :update, ["playlist", :id]
    publish_all :destroy, ["playlist", :id]
  end

  validations do
    # Customer-facing validations own localized messages for form errors.
    # Keep shape rules here instead of duplicating them as attribute constraints.
    validate present(:name) do
      message dgettext_noop("errors", "Playlist name is required")
    end

    validate string_length(:name, min: 3) do
      message dgettext_noop("errors", "Playlist name must be at least %{min} characters")
    end

    validate string_length(:name, max: 30) do
      message dgettext_noop("errors", "Playlist name cannot be longer than %{max} characters")
    end

    validate one_of(:icon, LucideIcon.names()) do
      message dgettext_noop("errors", "Playlist icon is invalid")
    end
  end

  attributes do
    uuid_v7_primary_key :id

    # The validations own the user-facing messages
    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :icon, :string do
      public? true
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :owner, User do
      allow_nil? false
      attribute_writable? false
    end

    has_many :items, PlaylistItem

    has_many :accesses, PlaylistAccess
  end

  calculations do
    calculate :editable_by?,
              :boolean,
              expr(
                owner_id == ^arg(:user_id) or
                  exists(accesses, user_id == ^arg(:user_id) and level == :edit)
              ) do
      description "Whether the User can Add to Playlist and Remove from Playlist: its owner and the Users with Edit access"
      argument :user_id, :uuid_v7, allow_nil?: false
    end

    calculate :holds_content?, :boolean, HoldsContent do
      argument :content_identity, ContentIdentity, allow_nil?: false
    end
  end

  aggregates do
    count :movie_count, [:items, :content] do
      filter expr(type == :movie)
    end

    count :tv_show_count, [:items, :content] do
      filter expr(type == :tv_show)
    end
  end
end
