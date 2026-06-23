defmodule WatchClub.MediaSources.Filesystem do
  @moduledoc """
  Filesystem-flavored configuration of a `Source`.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.MediaSources,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.MediaSources.Source
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
      description "Filesystem actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action(:read) do
      description "Instance Administrator and the system actor can read Filesystem"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if WatchClub.Checks.IsSystemActor
    end

    policy action([:create, :update, :destroy]) do
      description "Only the Instance Administrator can write Filesystem directly"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    publish :update, ["media_sources", "admin"]
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
    belongs_to :media_source, Source do
      primary_key? true
      allow_nil? false
      define_attribute? false
      source_attribute :id
    end
  end
end
