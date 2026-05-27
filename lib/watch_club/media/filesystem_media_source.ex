defmodule WatchClub.Media.FilesystemMediaSource do
  @moduledoc """
  Filesystem-flavored configuration of a `MediaSource`.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Media.MediaSource
  alias WatchClub.Shared.Changes.NormalizePath

  postgres do
    table "filesystem_media_sources"
    repo WatchClub.Repo

    references do
      reference :media_source, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:filesystem_path]
      change {NormalizePath, attribute: :filesystem_path}
    end

    update :update do
      primary? true
      accept [:filesystem_path]
      change {NormalizePath, attribute: :filesystem_path}
    end
  end

  policies do
    policy actor_absent() do
      description "FilesystemMediaSource actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action(:read) do
      description "Instance Administrator and the system actor can read FilesystemMediaSource"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if WatchClub.Checks.IsSystemActor
    end

    policy action([:create, :update, :destroy]) do
      description "Only the Instance Administrator can write FilesystemMediaSource directly"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub
    prefix "media_sources"

    publish :update, [[:id, nil]]
  end

  attributes do
    attribute :id, :uuid_v7 do
      primary_key? true
      allow_nil? false
    end

    attribute :filesystem_path, :string do
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :media_source, MediaSource do
      primary_key? true
      allow_nil? false
      define_attribute? false
      source_attribute :id
    end
  end
end
