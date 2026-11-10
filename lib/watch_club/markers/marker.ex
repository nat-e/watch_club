defmodule WatchClub.Markers.Marker do
  @moduledoc """
  A part of a Video that the Player lets a User skip: its Intro, Recap or Credits.
  The `detect` action finds them in the background, together for the TV Show Episodes of
  a season.
  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Markers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Markers.MarkerKind
  alias WatchClub.MediaCatalog.Video

  postgres do
    table "markers"
    repo WatchClub.Repo

    references do
      # The unique_kind_per_video index starts with video_id
      reference :video, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, create: [:video_id, :kind, :start_seconds, :end_seconds]]

    action :detect do
      description """
      Finds the Markers of the TV Show Episodes of one season, or of a single other Video.
      Reads each file for a few seconds: run it in the background.
      """

      argument :videos, {:array, :struct},
        allow_nil?: false,
        constraints: [items: [instance_of: Video]]

      run WatchClub.Markers.Marker.Actions.Detect
    end
  end

  policies do
    policy actor_absent() do
      description "Marker actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:read) do
      description "Any authenticated actor can read Markers"
      authorize_if always()
    end

    policy action_type([:create, :destroy, :action]) do
      description "Only the system actor can write or detect Markers"
      authorize_if actor_attribute_equals(:system?, true)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # For the Players playing the Video
    publish_all :create, ["video", :video_id]
    publish_all :destroy, ["video", :video_id]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :kind, MarkerKind do
      allow_nil? false
      public? true
    end

    attribute :start_seconds, :float do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :end_seconds, :float do
      allow_nil? false
      public? true
      constraints min: 0
    end
  end

  relationships do
    belongs_to :video, Video do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_kind_per_video, [:video_id, :kind]
  end
end
