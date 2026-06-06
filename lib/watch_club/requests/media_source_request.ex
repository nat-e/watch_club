defmodule WatchClub.Requests.MediaSourceRequest do
  @moduledoc """
  WatchClub's record of asking one request-capable `Source` to make one
  `Content` available. Singleton per `(content, media_source)`, shared by
  every `ContentRequest` for that content.

  The row is *born at submission* (created only after a successful add/adopt,
  so `external_resource_id` is never nil). Its `state` is **reconciled**, not
  driven by events: `create` and `refresh_status` both recompute it from the
  *arr's current truth via `RefreshState`. Any webhook (or a future poll) for
  the resource just calls `refresh_status` — so state never oscillates.

  The user-facing `ContentRequest` status is derived from these states plus
  Media; this resource never stores anything user-facing.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Requests,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Contents.Content
  alias WatchClub.MediaSources.Source
  alias WatchClub.Requests.MediaSourceRequest.Changes.RefreshState
  alias WatchClub.Requests.{ContentRequest, MediaSourceRequestState}

  postgres do
    table "media_source_requests"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :delete, on_update: :update
      reference :media_source, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read]

    # Created by the submit worker after a successful add/adopt. `state` is
    # recomputed from the *arr by RefreshState (not passed in). Upsert on the
    # singleton identity so a concurrent request can't duplicate it; on
    # conflict we refresh the external id and re-derive state.
    create :create do
      primary? true
      upsert? true
      upsert_identity :unique_content_source
      upsert_fields [:external_resource_id, :state]

      accept [:content_id, :media_source_id, :external_resource_id]

      change RefreshState

      change {WatchClub.Contents.Changes.NotifyContentChanged,
              content: :content, user: [:user_requests, :user]}
    end

    # Reconcile against the *arr's current truth. Called on any webhook/poll
    # for the resource. require_atomic? false: RefreshState makes an HTTP call.
    update :refresh_status do
      require_atomic? false
      accept []

      change RefreshState

      change {WatchClub.Contents.Changes.NotifyContentChanged,
              content: :content, user: [:user_requests, :user]}
    end

    destroy :destroy do
      primary? true

      require_atomic? false

      change {WatchClub.Contents.Changes.NotifyContentChanged,
              content: :content, user: [:user_requests, :user]}
    end
  end

  policies do
    policy actor_absent() do
      description "Media Source Request actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    # Not user-scoped and not sensitive (it reveals upstream request state for
    # a Content, not who asked). Readable by any authenticated actor so a
    # user's Content Request status can aggregate over it.
    policy action(:read) do
      description "Any authenticated actor can read Media Source Requests"
      authorize_if always()
    end

    policy action([:create, :refresh_status, :destroy]) do
      description "Media Source Requests are written only by the system actor (workers, webhooks)"
      authorize_if WatchClub.Checks.IsSystemActor
    end
  end

  attributes do
    uuid_v7_primary_key :id

    # Reconciled from the *arr; see RefreshState. Plain attribute, not a state
    # machine — any value can follow any other.
    attribute :state, MediaSourceRequestState do
      allow_nil? false
      default :submitted
      public? true
    end

    # The upstream system's own id for the resource it created or adopted
    # (Radarr movie id / Sonarr series id). Never nil — the row exists only
    # after a successful add/adopt — and used to match incoming webhooks.
    attribute :external_resource_id, :integer do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :content, Content do
      allow_nil? false
      public? true
    end

    belongs_to :media_source, Source do
      allow_nil? false
      public? true
    end

    has_many :user_requests, ContentRequest do
      source_attribute :content_id
      destination_attribute :content_id
    end
  end

  identities do
    identity :unique_content_source, [:content_id, :media_source_id]
  end
end
