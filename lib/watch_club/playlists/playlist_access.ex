defmodule WatchClub.Playlists.PlaylistAccess do
  @moduledoc """
  What a `User` can do with a `Playlist` shared with them: View it, or Edit it to also add and
  remove its Content. Read and written only through its Playlist, whose policies cover it.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Playlists,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Accounts.User
  alias WatchClub.Playlists.{Playlist, PlaylistAccessLevel}

  postgres do
    table "playlist_accesses"
    repo WatchClub.Repo

    references do
      reference :playlist, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, create: [:user_id, :level], update: [:level]]
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # The User's pages subscribe to the topic of the Playlist shared with them, and reload once
    # it isn't. A change of level reaches the Playlist's topic through Share Playlist.
    publish_all :create, ["user", :user_id]
    publish_all :destroy, ["user", :user_id]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :level, PlaylistAccessLevel do
      public? true
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :playlist, Playlist do
      allow_nil? false
    end

    belongs_to :user, User do
      allow_nil? false
    end
  end

  identities do
    identity :playlist_and_user, [:playlist_id, :user_id]
  end
end
