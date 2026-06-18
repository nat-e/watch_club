defmodule WatchClub.Requests.ContentRequest do
  @moduledoc """
  A user's request for WatchClub to make a piece of `Content` available for
  their personal consumption.

  Has **no stored status**: what the user sees in My Requests is derived at
  read time from this request's `MediaSourceRequest`s (shared per content)
  and the Content's Media. The `media_source_requests` relationship is keyed
  on `content_id`, not this row's id, because a Media Source Request is
  shared by every user's request for the same Content.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Requests,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [WatchClub.PubSubDefaults],
    notifiers: [WatchClub.Contents.Notifiers.ContentChangedNotifier]

  import Ash.Expr

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.Content
  alias WatchClub.Requests.ContentRequest.Changes.{CreateMediaSourceRequests, EnsureContentExists}
  alias WatchClub.Requests.{ContentRequestSort, ContentRequestStatusGroup, MediaSourceRequest}

  postgres do
    table "content_requests"
    repo WatchClub.Repo

    references do
      reference :user, on_delete: :delete, on_update: :update
      reference :content, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read]

    create :request do
      upsert? true
      upsert_identity :unique_user_content

      argument :content_identity, WatchClub.Contents.ContentIdentity, allow_nil?: false

      change relate_actor(:user)
      change EnsureContentExists
      change CreateMediaSourceRequests

      change {WatchClub.Contents.Changes.CreateContentNotification,
              content: :content, user: :user}
    end

    read :for_current_user do
      description "The acting user's own Content Requests, for the My Requests page."

      argument :content_type, :atom do
        allow_nil? true
        constraints one_of: [:movie, :tv_show, :book]
      end

      argument :status_group, ContentRequestStatusGroup, allow_nil?: true

      argument :sort, ContentRequestSort do
        default ContentRequestSort.default()
      end

      pagination keyset?: true, default_limit: 25, required?: false

      prepare build(filter: expr(content.type == ^arg(:content_type))) do
        where present(:content_type)
      end

      prepare build(filter: expr(status_group == ^arg(:status_group))) do
        where present(:status_group)
      end

      # Apply the requested sort, then load the read model and the content
      # (through its `:for_view` read action).
      prepare fn query, context ->
        query
        |> ContentRequestSort.sort_query(Ash.Query.get_argument(query, :sort))
        |> Ash.Query.load([
          :status,
          :status_group,
          :progress,
          content: Ash.Query.for_read(Content, :for_view, %{}, actor: context.actor)
        ])
      end
    end

    read :for_content do
      argument :content_id, :uuid, allow_nil?: false

      filter expr(content_id == ^arg(:content_id))
    end

    destroy :cancel do
      primary? true

      description "Remove the acting user's own request. Touches no Media, Library Item, or Media Source Request."

      # CreateContentNotification adds after_action hooks, so the destroy can't be atomic.
      require_atomic? false

      change {WatchClub.Contents.Changes.CreateContentNotification,
              content: :content, user: :user}
    end
  end

  policies do
    policy actor_absent() do
      description "Content Request actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    # Reads are filtered to the actor's own requests; the Instance
    # Administrator can inspect all.
    policy action([:read, :for_current_user]) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if actor_attribute_equals(:administrator?, true)
    end

    policy action(:for_content) do
      description "Only admin and system user can get all Content Requests for a content"
      authorize_if WatchClub.Checks.IsSystemActor
      authorize_if actor_attribute_equals(:administrator?, true)
    end

    policy action(:request) do
      description "Any authenticated user can request content for themselves"
      authorize_if always()
    end

    policy action(:cancel) do
      description "A user can cancel their own request; the Instance Administrator can cancel any"
      authorize_if expr(user_id == ^actor(:id))
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  pub_sub do
    prefix "content_requests"

    publish :request, ["user", :user_id]
    publish :cancel, ["user", :user_id]
  end

  attributes do
    uuid_v7_primary_key :id

    timestamps()
  end

  relationships do
    belongs_to :user, User do
      allow_nil? false
      attribute_writable? false
    end

    belongs_to :content, Content do
      allow_nil? false
      # Set by EnsureContentExists from the action arguments, not accepted.
      attribute_writable? false
    end

    # An MSR is shared by every user's request for the same Content, so this
    # is keyed on content_id rather than this row's primary key.
    has_many :media_source_requests, MediaSourceRequest do
      source_attribute :content_id
      destination_attribute :content_id
    end
  end

  calculations do
    calculate :progress,
              :integer,
              WatchClub.Requests.ContentRequest.Calculations.Progress do
      public? true
    end

    calculate :status,
              WatchClub.Requests.ContentRequestStatus,
              WatchClub.Requests.ContentRequest.Calculations.Status do
      public? true
    end

    calculate :status_group,
              ContentRequestStatusGroup,
              expr(
                cond do
                  status == :not_released -> :not_released
                  status == :not_found -> :not_found
                  status == :completed -> :completed
                  status == :failed -> :failed
                  status in [:requested, :downloading, :importing] -> :in_progress
                end
              ) do
      public? true
    end

    # MSR transitions, not this row, are what move; fall back to the row's
    # own updated_at when there are no requests yet.
    calculate :last_activity_at,
              :utc_datetime_usec,
              expr(fragment("coalesce(?, ?)", last_request_activity_at, updated_at)) do
      public? true
    end
  end

  aggregates do
    # Media Source Request states for this request's content (shared pool).
    count :request_count, :media_source_requests

    count :downloading_request_count, :media_source_requests do
      filter expr(state == :downloading)
    end

    count :partially_downloaded_request_count, :media_source_requests do
      filter expr(state == :partially_downloaded)
    end

    count :downloaded_request_count, :media_source_requests do
      filter expr(state == :downloaded)
    end

    count :not_released_request_count, :media_source_requests do
      filter expr(state == :not_released)
    end

    count :needs_attention_request_count, :media_source_requests do
      filter expr(state == :needs_attention)
    end

    # Submitted and still within the grace window — beyond it a submitted
    # request that hasn't advanced is treated as "no progress" (not_found).
    count :fresh_submitted_request_count, :media_source_requests do
      filter expr(state == :submitted and inserted_at > ago(5, :minute))
    end

    max :last_request_activity_at, :media_source_requests, :updated_at

    # Media presence (the fulfillment authority), independent of requests.
    count :movie_video_count, [:content, :movie, :videos]

    count :aired_episode_count, [:content, :tv_show, :episodes] do
      filter expr(not is_nil(air_date) and air_date <= fragment("CURRENT_DATE"))
    end

    count :aired_available_episode_count, [:content, :tv_show, :episodes] do
      filter expr(
               not is_nil(air_date) and air_date <= fragment("CURRENT_DATE") and
                 exists(videos, true)
             )
    end
  end

  identities do
    identity :unique_user_content, [:user_id, :content_id]
  end
end
