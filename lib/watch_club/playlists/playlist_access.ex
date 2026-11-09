defmodule WatchClub.Playlists.PlaylistAccess do
  @moduledoc """
  What a `User` can do with a `Playlist` shared with them: View it, or Edit it to also add and
  remove its Content. Read and written only through its Playlist, whose policies cover it.

  It's shared unseen from when Share Playlist gives it until the User opens their Playlists, and
  the Playlists tab's badge counts it meanwhile.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Playlists,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  require Ash.Query

  alias WatchClub.Accounts.User
  alias WatchClub.Playlists.{Playlist, PlaylistAccessLevel}

  postgres do
    table "playlist_accesses"
    repo WatchClub.Repo

    references do
      reference :playlist, on_delete: :delete
      reference :user, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [:read, :destroy, create: [:user_id, :level], update: [:level]]

    update :mark_shared_seen do
      accept []
      change set_attribute(:shared_unseen?, false)
    end

    action :mark_all_shared_seen do
      description "The actor opened their Playlists: none shared with them is shared unseen anymore."

      run fn _input, context ->
        __MODULE__
        |> Ash.Query.filter(user_id == ^context.actor.id and shared_unseen?)
        |> Ash.bulk_update!(:mark_shared_seen, %{}, Ash.Context.to_opts(context, notify?: true))

        :ok
      end
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # The User's pages subscribe to the topic of the Playlist shared with them, and reload once
    # it isn't. A change of level reaches the Playlist's topic through Share Playlist.
    publish_all :create, ["user", :user_id]
    publish_all :destroy, ["user", :user_id]
    # So that every page updates the Playlists tab's badge
    publish :mark_shared_seen, ["user", :user_id]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :level, PlaylistAccessLevel do
      public? true
      allow_nil? false
    end

    attribute :shared_unseen?, :boolean do
      allow_nil? false
      default true
      source :is_shared_unseen
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
    identity :playlist_and_user, [:playlist_id, :user_id] do
      message dgettext_noop("errors", "The playlist is already shared with this user")
    end
  end
end
