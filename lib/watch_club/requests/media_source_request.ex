defmodule WatchClub.Requests.MediaSourceRequest do
  @moduledoc """
  WatchClub's record of asking one request-capable `Source` to make one
  `Content` available. Singleton per `(content, media_source)`, shared by
  every `ContentRequest` for that content.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Requests,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Contents.Content
  alias WatchClub.MediaSources.Source
  alias WatchClub.Requests.Changes.UpdateContentRequest
  alias WatchClub.Requests.MediaSourceRequestStatus
  alias WatchClub.Requests.Workers.RefreshMediaSourceRequest

  postgres do
    table "media_source_requests"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :delete
      reference :media_source, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :create do
      description "Updates the MSR and the related Content Requests"
      primary? true
      upsert? true
      upsert_identity :unique_content_source
      upsert_fields [:external_resource_id, :status]

      accept [:content_id, :media_source_id, :external_resource_id]

      # Schedule the first refresh in 5 seconds
      change fn changeset, _ctx ->
        Ash.Changeset.after_action(changeset, fn changeset, updated_request ->
          RefreshMediaSourceRequest.new_job(updated_request.id, scheduled_in: 5)
          |> OpentelemetryOban.insert!()

          {:ok, updated_request}
        end)
      end

      change UpdateContentRequest
    end

    update :update do
      description "Updates the MSR and the related Content Requests if necessary"
      primary? true
      require_atomic? false
      accept [:status, :download_progress]

      change UpdateContentRequest
    end

    destroy :destroy do
      primary? true

      require_atomic? false
      change UpdateContentRequest
    end
  end

  policies do
    policy actor_absent() do
      description "Media Source Request actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    # Not user-scoped and not sensitive (it reveals upstream request status for
    # a Content, not who asked). Readable by any authenticated actor so a
    # user's Content Request status can aggregate over it.
    policy action_type(:read) do
      description "Any authenticated actor can read Media Source Requests"
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      description "Media Source Requests are written only by the system actor (workers, webhooks)"
      authorize_if WatchClub.Checks.IsSystemActor
    end
  end

  attributes do
    uuid_v7_primary_key :id

    # Reconciled from the *arr; see RefreshMediaSourceRequest. Plain attribute,
    # not a status machine — any value can follow any other.
    attribute :status, MediaSourceRequestStatus do
      allow_nil? false
      default :searching
      public? true
    end

    # The download progress of the request in %.
    #
    # - 0 when the request is :searching
    # - Between 0 and 100 when the request is :downloading / :partially_downloaded
    # - 100 when the request is in a status after downloading
    #
    # For Movies/Books, this will be the progress of the downloaded file in the Radarr/Chaptarr queue
    # For TV Shows, this will be the sum of the progress of all the downloaded files in
    # the Sonarr queue (seasons or episodes), divided by the number of episodes.
    attribute :download_progress, :float do
      allow_nil? false
      default 0.0
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
  end

  calculations do
    # An internal sorting rank for comparing requests of the same Content
    calculate :status_rank,
              :integer,
              expr(
                cond do
                  status == :downloaded -> 4
                  status == :downloading -> 3
                  status == :needs_attention -> 2
                  status == :not_released -> 1
                  status == :searching -> 0
                end
              ) do
      public? false
    end
  end

  identities do
    identity :unique_content_source, [:content_id, :media_source_id]
  end
end
